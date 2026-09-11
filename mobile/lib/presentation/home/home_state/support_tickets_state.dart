// Ticket di supporto: invio, allegati, registrazione vocale, thread e diagnostica.

part of '../home_screen.dart';

mixin _SupportTicketsState on _HomeScreenStateBase {
  @override
  void _logDiagnostic(
    String event, {
    Map<String, Object?> details = const <String, Object?>{},
  }) {
    _diagnosticLogService.add(event, details: details);
  }

  String _buildTicketDiagnosticLogs() {
    final accountEmail = _accountSession?.user.email;
    final lines = <String>[
      'Contesto ticket app',
      'timestamp=${DateTime.now().toIso8601String()}',
      'sezioneAttiva=${_selectedSection.name}',
      'apiBase=${_snapshot?.apiBaseUrl ?? "n/d"}',
      'accountCloud=${accountEmail == null ? "non loggato" : _maskEmailForDiagnostic(accountEmail)}',
      'backupCloudDisponibile=$_hasCloudBackupAvailable',
      'ultimoBackupAt=${_lastCloudBackupAt?.toIso8601String() ?? "n/d"}',
      'ultimoTentativoBackupAt=${_lastCloudBackupAttemptAt?.toIso8601String() ?? "n/d"}',
      'ultimoBackupOk=${_lastCloudBackupSucceeded?.toString() ?? "n/d"}',
      '',
      _diagnosticLogService.exportText(header: 'Log eventi'),
    ];

    final payload = lines.join('\n');
    if (payload.length <= maxTicketDiagnosticLogChars) {
      return payload;
    }

    final cutIndex = payload.length - maxTicketDiagnosticLogChars;
    return '...log troncati ($cutIndex caratteri rimossi)\n${payload.substring(cutIndex)}';
  }

  String _maskEmailForDiagnostic(String email) {
    final normalized = email.trim();
    final atIndex = normalized.indexOf('@');
    if (atIndex <= 1 || atIndex >= normalized.length - 1) {
      return normalized;
    }

    final localPart = normalized.substring(0, atIndex);
    final domainPart = normalized.substring(atIndex + 1);
    final hiddenCharacters = List.filled(
      math.max(0, localPart.length - 2),
      '*',
    ).join();
    final maskedLocal = localPart.length <= 2
        ? '${localPart[0]}*'
        : '${localPart[0]}$hiddenCharacters${localPart[localPart.length - 1]}';
    return '$maskedLocal@$domainPart';
  }

  TrackedSupportTicket? _trackedTicketById(String? ticketId) {
    if (ticketId == null) {
      return null;
    }

    for (final ticket in _trackedTickets) {
      if (ticket.id == ticketId) {
        return ticket;
      }
    }

    return null;
  }

  int _countUnreadAdminReplies(
    List<TrackedSupportTicket> trackedTickets,
    Map<String, SupportTicketThread> ticketThreadsById,
  ) {
    var unreadReplies = 0;
    for (final trackedTicket in trackedTickets) {
      final thread = ticketThreadsById[trackedTicket.id];
      if (thread == null) {
        continue;
      }

      unreadReplies += math.max(
        0,
        thread.adminReplyCount - trackedTicket.lastSeenAdminReplyCount,
      );
    }

    return unreadReplies;
  }

  void _startTicketNotificationPolling() {
    _ticketNotificationTimer?.cancel();
    _ticketNotificationTimer = Timer.periodic(
      ticketNotificationPollingInterval,
      (_) {
        if (!mounted) {
          return;
        }
        unawaited(_refreshTrackedSupportTickets(notifyAboutNewReplies: true));
      },
    );
  }

  String _buildTicketReplyNotificationMessage(
    List<({String subject, int newReplies})> updates,
  ) {
    if (updates.isEmpty) {
      return 'Nuove risposte ticket disponibili.';
    }

    if (updates.length == 1) {
      final update = updates.first;
      if (update.newReplies == 1) {
        return 'Nuova risposta su "${update.subject}".';
      }
      return 'Hai ${update.newReplies} nuove risposte su "${update.subject}".';
    }

    final totalNewReplies = updates.fold<int>(
      0,
      (total, update) => total + update.newReplies,
    );
    if (totalNewReplies == updates.length) {
      return 'Hai nuove risposte su ${updates.length} ticket.';
    }

    return 'Hai $totalNewReplies nuove risposte su ${updates.length} ticket.';
  }

  Future<void> _markTrackedTicketRepliesNotified(
    List<({String ticketId, int adminReplyCount})> updates,
  ) async {
    if (updates.isEmpty) {
      return;
    }

    final latestAdminReplyCountByTicket = <String, int>{};
    for (final update in updates) {
      final previousValue = latestAdminReplyCountByTicket[update.ticketId];
      if (previousValue == null || update.adminReplyCount > previousValue) {
        latestAdminReplyCountByTicket[update.ticketId] = update.adminReplyCount;
      }
    }

    await widget.supportTicketStore.markAdminRepliesNotifiedBatch(
      adminReplyCountByTicketId: latestAdminReplyCountByTicket,
    );
    if (!mounted) {
      return;
    }

    var hasChanges = false;
    final nextTrackedTickets = _trackedTickets
        .map((ticket) {
          final latestAdminReplyCount =
              latestAdminReplyCountByTicket[ticket.id];
          if (latestAdminReplyCount == null ||
              latestAdminReplyCount <= ticket.lastNotifiedAdminReplyCount) {
            return ticket;
          }
          hasChanges = true;
          return ticket.copyWith(
            lastNotifiedAdminReplyCount: latestAdminReplyCount,
          );
        })
        .toList(growable: false);
    if (!hasChanges) {
      return;
    }

    setState(() {
      _trackedTickets = nextTrackedTickets;
    });
  }

  @override
  Future<void> _refreshTrackedSupportTickets({
    bool notifyAboutNewReplies = false,
  }) async {
    if (_isLoadingTicketThreads) {
      return;
    }

    setState(() {
      _isLoadingTicketThreads = true;
    });

    try {
      final trackedTickets = await widget.supportTicketStore
          .loadTrackedTickets();
      if (trackedTickets.isEmpty) {
        if (!mounted) {
          return;
        }

        setState(() {
          _trackedTickets = const [];
          _ticketThreadsById = const {};
          _selectedTrackedTicketId = null;
          _unreadTicketReplyCount = 0;
          _isLoadingTicketThreads = false;
        });
        return;
      }

      final fetchedEntries = await Future.wait(
        trackedTickets.map((trackedTicket) async {
          try {
            final thread = await widget.dashboardService.fetchSupportTicket(
              ticketId: trackedTicket.id,
            );
            return (tracked: trackedTicket, thread: thread);
          } catch (_) {
            return null;
          }
        }),
      );

      final nextThreadsById = <String, SupportTicketThread>{};
      final nextTrackedTickets = <TrackedSupportTicket>[];
      final newRepliesToNotify =
          <
            ({
              String ticketId,
              String subject,
              int newReplies,
              int adminReplyCount,
            })
          >[];
      for (var index = 0; index < trackedTickets.length; index++) {
        final trackedTicket = trackedTickets[index];
        final entry = fetchedEntries[index];
        if (entry == null) {
          nextTrackedTickets.add(trackedTicket);
          final cachedThread = _ticketThreadsById[trackedTicket.id];
          if (cachedThread != null) {
            nextThreadsById[trackedTicket.id] = cachedThread;
          }
          continue;
        }

        nextThreadsById[entry.thread.id] = entry.thread;
        nextTrackedTickets.add(
          entry.tracked.copyWith(
            subject: entry.thread.subject,
            createdAt: entry.thread.createdAt,
          ),
        );

        final unreadReplies = math.max(
          0,
          entry.thread.adminReplyCount - entry.tracked.lastSeenAdminReplyCount,
        );
        if (notifyAboutNewReplies && unreadReplies > 0) {
          final newReplies = math.max(
            0,
            entry.thread.adminReplyCount -
                entry.tracked.lastNotifiedAdminReplyCount,
          );
          if (newReplies > 0) {
            newRepliesToNotify.add((
              ticketId: entry.thread.id,
              subject: entry.thread.subject,
              newReplies: newReplies,
              adminReplyCount: entry.thread.adminReplyCount,
            ));
          }
        }
      }

      final selectedTicketId =
          nextThreadsById.containsKey(_selectedTrackedTicketId)
          ? _selectedTrackedTicketId
          : (nextTrackedTickets.isEmpty ? null : nextTrackedTickets.first.id);
      final unreadTicketReplyCount = _countUnreadAdminReplies(
        nextTrackedTickets,
        nextThreadsById,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _trackedTickets = nextTrackedTickets;
        _ticketThreadsById = nextThreadsById;
        _selectedTrackedTicketId = selectedTicketId;
        _unreadTicketReplyCount = unreadTicketReplyCount;
        _isLoadingTicketThreads = false;
      });

      if (notifyAboutNewReplies && newRepliesToNotify.isNotEmpty) {
        await _markTrackedTicketRepliesNotified(
          newRepliesToNotify
              .map(
                (update) => (
                  ticketId: update.ticketId,
                  adminReplyCount: update.adminReplyCount,
                ),
              )
              .toList(growable: false),
        );
      }

      if (notifyAboutNewReplies && newRepliesToNotify.isNotEmpty && mounted) {
        final message = _buildTicketReplyNotificationMessage(
          newRepliesToNotify
              .map(
                (update) =>
                    (subject: update.subject, newReplies: update.newReplies),
              )
              .toList(growable: false),
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
        unawaited(
          _localNotificationService.notifyTicketReplies(message: message),
        );
      }

      final currentSelectedTicketId = selectedTicketId;
      if (_selectedSection == HomeSection.ticket &&
          currentSelectedTicketId != null) {
        unawaited(_markTrackedTicketRepliesSeen(currentSelectedTicketId));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingTicketThreads = false;
      });
    }
  }

  Future<void> _upsertTrackedSupportTicket(SupportTicketThread thread) async {
    final trackedTicket = _trackedTicketById(thread.id);
    final nextTrackedTicket = TrackedSupportTicket(
      id: thread.id,
      subject: thread.subject,
      createdAt: thread.createdAt,
      lastSeenAdminReplyCount:
          trackedTicket?.lastSeenAdminReplyCount ?? thread.adminReplyCount,
      lastNotifiedAdminReplyCount:
          trackedTicket?.lastNotifiedAdminReplyCount ?? thread.adminReplyCount,
    );
    await widget.supportTicketStore.upsertTrackedTicket(nextTrackedTicket);
  }

  Future<void> _markTrackedTicketRepliesSeen(String ticketId) async {
    final thread = _ticketThreadsById[ticketId];
    if (thread == null) {
      return;
    }

    final trackedTicket = _trackedTicketById(ticketId);
    if (trackedTicket == null) {
      return;
    }
    if (trackedTicket.lastSeenAdminReplyCount >= thread.adminReplyCount &&
        trackedTicket.lastNotifiedAdminReplyCount >= thread.adminReplyCount) {
      return;
    }

    await widget.supportTicketStore.markAdminRepliesSeenAndNotified(
      ticketId: ticketId,
      adminReplyCount: thread.adminReplyCount,
    );
    if (!mounted) {
      return;
    }

    final latestReplyCount = thread.adminReplyCount;
    final nextTrackedTickets = _trackedTickets
        .map(
          (ticket) => ticket.id == ticketId
              ? ticket.copyWith(
                  lastSeenAdminReplyCount: latestReplyCount,
                  lastNotifiedAdminReplyCount: latestReplyCount,
                )
              : ticket,
        )
        .toList(growable: false);
    setState(() {
      _trackedTickets = nextTrackedTickets;
      _unreadTicketReplyCount = _countUnreadAdminReplies(
        nextTrackedTickets,
        _ticketThreadsById,
      );
    });
  }

  @override
  Future<void> _selectTrackedSupportTicket(String ticketId) async {
    setState(() {
      _selectedTrackedTicketId = ticketId;
    });
    await _markTrackedTicketRepliesSeen(ticketId);
  }

  @override
  Future<void> _recoverTrackedSupportTicketById() async {
    final ticketId = _ticketRecoveryIdController.text.trim();
    if (ticketId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci il codice ticket.')),
      );
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(ticketId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Codice ticket non valido.')),
      );
      return;
    }
    if (_isRecoveringTrackedTicket) {
      return;
    }

    setState(() {
      _isRecoveringTrackedTicket = true;
    });

    try {
      final thread = await widget.dashboardService.fetchSupportTicket(
        ticketId: ticketId,
      );
      await _upsertTrackedSupportTicket(thread);
      if (!mounted) {
        return;
      }

      _ticketRecoveryIdController.clear();
      await _refreshTrackedSupportTickets(notifyAboutNewReplies: false);
      if (!mounted) {
        return;
      }

      await _selectTrackedSupportTicket(thread.id);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ticket ${thread.id} recuperato. Le prossime risposte arriveranno qui.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _humanizeError(
              error,
              apiBaseUrl: _snapshot?.apiBaseUrl,
              isTicketRequest: true,
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRecoveringTrackedTicket = false;
        });
      }
    }
  }

  @override
  Future<void> _submitSupportTicketReply() async {
    final selectedTicketId = _selectedTrackedTicketId;
    if (selectedTicketId == null) {
      return;
    }

    final selectedThread = _ticketThreadsById[selectedTicketId];
    if (selectedThread != null &&
        selectedThread.status == SupportTicketStatus.closed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Questo ticket e chiuso e non puo ricevere altre risposte.',
          ),
        ),
      );
      return;
    }

    final message = _ticketReplyController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scrivi una risposta prima di inviarla.')),
      );
      return;
    }

    setState(() {
      _isSubmittingTicketReply = true;
    });

    try {
      final updatedThread = await widget.dashboardService.replyToSupportTicket(
        ticketId: selectedTicketId,
        message: message,
      );
      await _upsertTrackedSupportTicket(updatedThread);
      if (!mounted) {
        return;
      }

      _ticketReplyController.clear();
      final nextThreadsById = Map<String, SupportTicketThread>.from(
        _ticketThreadsById,
      )..[updatedThread.id] = updatedThread;
      setState(() {
        _ticketThreadsById = nextThreadsById;
        _isSubmittingTicketReply = false;
      });
      await _markTrackedTicketRepliesSeen(updatedThread.id);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Risposta inviata correttamente.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isSubmittingTicketReply = false;
        _errorMessage = _humanizeError(
          error,
          apiBaseUrl: _snapshot?.apiBaseUrl,
          isTicketRequest: true,
        );
      });
    }
  }

  @override
  Future<void> _submitSupportTicket() async {
    if (_isRecordingTicketVoice) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Completa o annulla la registrazione vocale prima di inviare il ticket.',
          ),
        ),
      );
      return;
    }

    final isValid = _ticketFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }

    setState(() {
      _isSubmittingTicket = true;
      _errorMessage = null;
    });

    try {
      _logDiagnostic(
        'ticket.submit.start',
        details: <String, Object?>{
          'category': _selectedTicketCategory.apiValue,
          'attachments': _ticketAttachments.length,
          'includeDiagnosticLogs': _includeDiagnosticLogsInTicket,
        },
      );
      final clientLogs = _includeDiagnosticLogsInTicket
          ? _buildTicketDiagnosticLogs()
          : null;
      final createdThread = await widget.dashboardService.submitSupportTicket(
        category: _selectedTicketCategory,
        name: _ticketNameController.text.trim().isEmpty
            ? null
            : _ticketNameController.text.trim(),
        email: _ticketEmailController.text.trim().isEmpty
            ? null
            : _ticketEmailController.text.trim(),
        subject: _ticketSubjectController.text.trim(),
        message: _ticketMessageController.text.trim(),
        appVersion: _ticketAppVersionController.text.trim().isEmpty
            ? null
            : _ticketAppVersionController.text.trim(),
        clientLogs: clientLogs,
        attachments: List<SupportTicketUploadAttachment>.from(
          _ticketAttachments,
        ),
      );

      if (!mounted) {
        return;
      }

      await _upsertTrackedSupportTicket(createdThread);
      if (!mounted) {
        return;
      }
      final nextThreadsById = Map<String, SupportTicketThread>.from(
        _ticketThreadsById,
      )..[createdThread.id] = createdThread;
      _ticketSubjectController.clear();
      _ticketMessageController.clear();
      _ticketRecoveryIdController.text = createdThread.id;
      setState(() {
        _ticketAttachments = const [];
        _trackedTickets = [
          TrackedSupportTicket(
            id: createdThread.id,
            subject: createdThread.subject,
            createdAt: createdThread.createdAt,
            lastSeenAdminReplyCount: createdThread.adminReplyCount,
            lastNotifiedAdminReplyCount: createdThread.adminReplyCount,
          ),
          ..._trackedTickets.where((ticket) => ticket.id != createdThread.id),
        ];
        _ticketThreadsById = nextThreadsById;
        _selectedTrackedTicketId = createdThread.id;
        _selectedSection = HomeSection.ticket;
        _unreadTicketReplyCount = _countUnreadAdminReplies([
          TrackedSupportTicket(
            id: createdThread.id,
            subject: createdThread.subject,
            createdAt: createdThread.createdAt,
            lastSeenAdminReplyCount: createdThread.adminReplyCount,
            lastNotifiedAdminReplyCount: createdThread.adminReplyCount,
          ),
          ..._trackedTickets.where((ticket) => ticket.id != createdThread.id),
        ], nextThreadsById);
        _isSubmittingTicket = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ticket inviato. Codice ticket: ${createdThread.id}'),
        ),
      );
      _logDiagnostic(
        'ticket.submit.ok',
        details: <String, Object?>{'ticketId': createdThread.id},
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = _humanizeError(
          error,
          apiBaseUrl: _snapshot?.apiBaseUrl,
          isTicketRequest: true,
        );
        _isSubmittingTicket = false;
      });
      _logDiagnostic(
        'ticket.submit.error',
        details: <String, Object?>{'error': error.toString()},
      );
    }
  }

  @override
  Future<void> _pickTicketAttachments() async {
    if (_isSubmittingTicket) {
      return;
    }

    final remainingSlots = maxTicketAttachments - _ticketAttachments.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Puoi allegare al massimo 3 file per ticket.'),
        ),
      );
      return;
    }

    try {
      final selectedImages = await _ticketImagePicker.pickMultiImage(
        requestFullMetadata: false,
      );
      if (selectedImages.isEmpty || !mounted) {
        return;
      }

      final nextAttachments = List<SupportTicketUploadAttachment>.from(
        _ticketAttachments,
      );
      var addedCount = 0;
      var skippedCount = 0;
      for (final selectedImage in selectedImages) {
        if (nextAttachments.length >= maxTicketAttachments) {
          skippedCount += 1;
          continue;
        }

        final fileName = selectedImage.name;
        final contentType = _ticketAttachmentContentTypeForFileName(fileName);
        final bytes = await selectedImage.readAsBytes();
        if (contentType == null ||
            !contentType.startsWith('image/') ||
            bytes.isEmpty ||
            bytes.lengthInBytes > maxTicketAttachmentBytes) {
          skippedCount += 1;
          continue;
        }

        nextAttachments.add(
          SupportTicketUploadAttachment(
            fileName: fileName,
            contentType: contentType,
            bytes: bytes,
          ),
        );
        addedCount += 1;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _ticketAttachments = nextAttachments;
      });

      if (addedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nessuno screenshot valido selezionato. Usa PNG, JPG o WEBP fino a 4 MB.',
            ),
          ),
        );
      } else if (skippedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Aggiunti $addedCount screenshot. Alcuni file sono stati ignorati per formato, peso o limite massimo.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile aprire la galleria screenshot.'),
        ),
      );
    }
  }

  @override
  Future<void> _pickTicketVoiceAttachments() async {
    if (_isSubmittingTicket) {
      return;
    }

    final remainingSlots = maxTicketAttachments - _ticketAttachments.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Puoi allegare al massimo 3 file per ticket.'),
        ),
      );
      return;
    }

    try {
      final selectedAudio = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true,
        type: FileType.custom,
        allowedExtensions: ticketAudioAttachmentExtensions,
      );
      if (selectedAudio == null || selectedAudio.files.isEmpty || !mounted) {
        return;
      }

      final nextAttachments = List<SupportTicketUploadAttachment>.from(
        _ticketAttachments,
      );
      var addedCount = 0;
      var skippedCount = 0;
      for (final selectedFile in selectedAudio.files) {
        if (nextAttachments.length >= maxTicketAttachments) {
          skippedCount += 1;
          continue;
        }

        final fileName = selectedFile.name;
        final contentType = _ticketAttachmentContentTypeForFileName(fileName);
        final bytes = selectedFile.bytes;
        if (contentType == null ||
            !_isAudioTicketAttachmentContentType(contentType) ||
            bytes == null ||
            bytes.isEmpty ||
            bytes.lengthInBytes > maxTicketAttachmentBytes) {
          skippedCount += 1;
          continue;
        }

        nextAttachments.add(
          SupportTicketUploadAttachment(
            fileName: fileName,
            contentType: contentType,
            bytes: bytes,
          ),
        );
        addedCount += 1;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _ticketAttachments = nextAttachments;
      });

      if (addedCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nessun vocale valido selezionato. Usa M4A, MP3, WAV, OGG, AAC o WEBM fino a 4 MB.',
            ),
          ),
        );
      } else if (skippedCount > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Aggiunti $addedCount vocali. Alcuni file sono stati ignorati per formato, peso o limite massimo.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossibile aprire il selettore file vocali.'),
        ),
      );
    }
  }

  @override
  Future<void> _recordTicketVoiceAttachment() async {
    if (_isSubmittingTicket || _isRecordingTicketVoice) {
      return;
    }

    if (!Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La registrazione vocale diretta e disponibile solo su Android.',
          ),
        ),
      );
      return;
    }

    final remainingSlots = maxTicketAttachments - _ticketAttachments.length;
    if (remainingSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Puoi allegare al massimo 3 file per ticket.'),
        ),
      );
      return;
    }

    String? outputPath;
    try {
      final hasPermission = await _ticketAudioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permesso microfono non concesso. Abilitalo per registrare un vocale.',
            ),
          ),
        );
        return;
      }

      final tempDirectory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      outputPath = '${tempDirectory.path}/ticket-voice-$timestamp.m4a';

      await _ticketAudioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: outputPath,
      );

      if (!mounted) {
        await _ticketAudioRecorder.cancel();
        return;
      }

      setState(() {
        _isRecordingTicketVoice = true;
      });

      final action = await showDialog<_TicketVoiceRecordingAction>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Registra vocale'),
            content: const Text(
              'Registrazione in corso. Quando hai finito premi "Termina e allega".',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_TicketVoiceRecordingAction.cancel),
                child: const Text('Annulla'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(
                  dialogContext,
                ).pop(_TicketVoiceRecordingAction.save),
                child: const Text('Termina e allega'),
              ),
            ],
          );
        },
      );

      if (action == _TicketVoiceRecordingAction.save) {
        final recordedPath = await _ticketAudioRecorder.stop();
        final normalizedPath = (recordedPath ?? '').trim();
        if (normalizedPath.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Registrazione non completata. Riprova a registrare il vocale.',
                ),
              ),
            );
          }
          return;
        }

        final voiceBytes = await File(normalizedPath).readAsBytes();
        if (!mounted) {
          return;
        }

        if (voiceBytes.isEmpty ||
            voiceBytes.lengthInBytes > maxTicketAttachmentBytes) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Vocale non valido o troppo grande. Limite 4 MB per allegato.',
              ),
            ),
          );
          return;
        }

        if (_ticketAttachments.length >= maxTicketAttachments) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Puoi allegare al massimo 3 file per ticket.'),
            ),
          );
          return;
        }

        final attachment = SupportTicketUploadAttachment(
          fileName: 'vocale-$timestamp.m4a',
          contentType: 'audio/mp4',
          bytes: voiceBytes,
        );
        setState(() {
          _ticketAttachments = [..._ticketAttachments, attachment];
        });
      } else {
        await _ticketAudioRecorder.cancel();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossibile registrare il vocale in questo momento.',
            ),
          ),
        );
      }
      await _ticketAudioRecorder.cancel().catchError((_) {});
    } finally {
      if (outputPath != null) {
        unawaited(
          File(outputPath).delete().then<void>((_) {}).catchError((_) {}),
        );
      }
      if (mounted) {
        setState(() {
          _isRecordingTicketVoice = false;
        });
      }
    }
  }

  @override
  void _removeTicketAttachmentAt(int index) {
    if (index < 0 || index >= _ticketAttachments.length) {
      return;
    }

    setState(() {
      _ticketAttachments = [
        for (var i = 0; i < _ticketAttachments.length; i += 1)
          if (i != index) _ticketAttachments[i],
      ];
    });
  }

  String? _ticketAttachmentContentTypeForFileName(String fileName) {
    final lowerFileName = fileName.toLowerCase();
    if (lowerFileName.endsWith('.png')) {
      return 'image/png';
    }
    if (lowerFileName.endsWith('.jpg') || lowerFileName.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowerFileName.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lowerFileName.endsWith('.m4a')) {
      return 'audio/mp4';
    }
    if (lowerFileName.endsWith('.mp3')) {
      return 'audio/mpeg';
    }
    if (lowerFileName.endsWith('.wav')) {
      return 'audio/wav';
    }
    if (lowerFileName.endsWith('.ogg')) {
      return 'audio/ogg';
    }
    if (lowerFileName.endsWith('.aac')) {
      return 'audio/aac';
    }
    if (lowerFileName.endsWith('.webm')) {
      return 'audio/webm';
    }
    return null;
  }

  bool _isAudioTicketAttachmentContentType(String contentType) {
    return contentType.startsWith('audio/');
  }
}
