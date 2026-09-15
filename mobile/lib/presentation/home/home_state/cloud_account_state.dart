// Account cloud: accesso, registrazione, recupero password e backup.

part of '../home_screen.dart';

mixin _CloudAccountState on _HomeScreenStateBase {
  bool get _isCloudBackupEnabled =>
      widget.accountService != null && _accountSession != null;

  @override
  Future<void> _triggerManualCloudBackup() {
    return _queueCloudBackup(showFeedback: true);
  }

  bool _isUnauthorizedApiError(Object error) {
    return error is ApiException &&
        (error.statusCode == 401 || error.statusCode == 403);
  }

  Future<void> _handleInvalidCloudSession({required bool showFeedback}) async {
    _logDiagnostic(
      'cloud.session.invalid',
      details: <String, Object?>{'showFeedback': showFeedback},
    );
    if (widget.accountService != null) {
      try {
        await widget.accountService!.logout();
      } catch (_) {
        // Best effort: local reset below is still enough to recover.
      }
    }

    if (!mounted) {
      return;
    }

    const message =
        'Accesso cloud non piu valido sul server. Ti ho disconnesso dal cloud: apri Profilo, accedi di nuovo e riprova.';
    setState(() {
      _accountSession = null;
      _accountAuthMode = AccountAuthMode.login;
      _hasCloudBackupAvailable = false;
      _lastCloudBackupAt = null;
      _lastCloudBackupAttemptAt = null;
      _isLoadingCloudBackupStatus = false;
      _isRestoringCloudBackup = false;
      _isSyncingCloudBackup = false;
      _lastCloudBackupSucceeded = false;
      _lastCloudBackupFeedback = message;
    });

    if (!showFeedback) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: const Text(message),
        duration: const Duration(seconds: 7),
        action: SnackBarAction(
          label: 'Apri profilo',
          onPressed: () {
            if (!mounted) {
              return;
            }

            setState(() {
              _goToSection(HomeSection.profile);
            });
          },
        ),
      ),
    );
  }

  Future<void> _refreshCloudBackupStatus({bool silent = false}) async {
    if (!_isCloudBackupEnabled ||
        widget.accountService == null ||
        _accountSession == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingCloudBackupStatus = true;
      });
    }

    try {
      _logDiagnostic(
        'cloud.backup.status.start',
        details: <String, Object?>{'silent': silent},
      );
      final status = await widget.accountService!.loadCloudBackupStatus(
        session: _accountSession,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCloudBackupStatus = false;
        _hasCloudBackupAvailable = status.hasBackup;
        _lastCloudBackupAt = status.hasBackup ? status.updatedAt : null;
      });
      _logDiagnostic(
        'cloud.backup.status.ok',
        details: <String, Object?>{
          'hasBackup': status.hasBackup,
          'updatedAt': status.updatedAt?.toIso8601String(),
        },
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (_isUnauthorizedApiError(error)) {
        _logDiagnostic(
          'cloud.backup.status.unauthorized',
          details: <String, Object?>{'error': error.toString()},
        );
        await _handleInvalidCloudSession(showFeedback: !silent);
        return;
      }

      setState(() {
        _isLoadingCloudBackupStatus = false;
      });
      _logDiagnostic(
        'cloud.backup.status.error',
        details: <String, Object?>{'error': error.toString()},
      );
      if (!silent) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
      }
    }
  }

  @override
  Future<void> _queueCloudBackup({bool showFeedback = false}) async {
    if (!_isCloudBackupEnabled) {
      return;
    }

    if (_isSyncingCloudBackup) {
      _cloudBackupQueued = true;
      _logDiagnostic(
        'cloud.backup.queued',
        details: <String, Object?>{'reason': 'already_running'},
      );
      return;
    }

    final attemptedAt = DateTime.now();
    setState(() {
      _isSyncingCloudBackup = true;
      _lastCloudBackupAttemptAt = attemptedAt;
    });

    var rerunQueuedBackup = false;
    try {
      _logDiagnostic(
        'cloud.backup.start',
        details: <String, Object?>{
          'showFeedback': showFeedback,
          'attemptedAt': attemptedAt.toIso8601String(),
        },
      );
      final backupStatus = await widget.accountService!.backupToCloud();
      if (!mounted) {
        return;
      }

      final savedAt = backupStatus.updatedAt ?? attemptedAt;
      final droppedItemsCount = backupStatus.droppedItemsCount;
      final baseSuccessMessage =
          'Backup cloud completato alle ${formatTicketDateTime(savedAt)}.';
      final successMessage = droppedItemsCount > 0
          ? '$baseSuccessMessage Ho ignorato $droppedItemsCount voce${droppedItemsCount == 1 ? '' : 'i'} non valida${droppedItemsCount == 1 ? '' : 'e'} per evitare il blocco del backup.'
          : baseSuccessMessage;
      setState(() {
        _hasCloudBackupAvailable = true;
        _lastCloudBackupAt = savedAt;
        _lastCloudBackupSucceeded = true;
        _lastCloudBackupFeedback = successMessage;
      });
      _logDiagnostic(
        'cloud.backup.ok',
        details: <String, Object?>{
          'savedAt': savedAt.toIso8601String(),
          'droppedItems': droppedItemsCount,
        },
      );

      if (showFeedback) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (_isUnauthorizedApiError(error)) {
        _logDiagnostic(
          'cloud.backup.unauthorized',
          details: <String, Object?>{'error': error.toString()},
        );
        await _handleInvalidCloudSession(showFeedback: showFeedback);
      } else {
        final message = _humanizeError(error);
        setState(() {
          _lastCloudBackupSucceeded = false;
          _lastCloudBackupFeedback = message;
        });
        if (showFeedback) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
        _logDiagnostic(
          'cloud.backup.error',
          details: <String, Object?>{
            'message': message,
            'error': error.toString(),
          },
        );
      }
    } finally {
      if (mounted) {
        rerunQueuedBackup = _cloudBackupQueued;
        if (_cloudBackupQueued) {
          _cloudBackupQueued = false;
        }
        setState(() {
          _isSyncingCloudBackup = false;
        });
      }
    }

    if (rerunQueuedBackup) {
      unawaited(_queueCloudBackup());
    }
  }

  void _openAccountRegistrationFlow() {
    if (!mounted) {
      return;
    }

    setState(() {
      _goToSection(HomeSection.profile);
      _accountAuthMode = AccountAuthMode.register;
    });
  }

  bool _isLikelyValidEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());
  }

  Future<String?> _promptRecoveryEmail() async {
    final emailController = TextEditingController(
      text: _accountEmailController.text.trim(),
    );
    final formKey = GlobalKey<FormState>();

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Recupera password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inserisci la tua email: carico le 2 domande di sicurezza.',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) {
                    final emailValue = value?.trim() ?? '';
                    return _isLikelyValidEmail(emailValue)
                        ? null
                        : 'Inserisci un email valida.';
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                final isValid = formKey.currentState?.validate() ?? false;
                if (!isValid) {
                  return;
                }

                Navigator.of(dialogContext).pop(emailController.text.trim());
              },
              child: const Text('Continua'),
            ),
          ],
        );
      },
    );

    emailController.dispose();
    return email;
  }

  Future<({String answerOne, String answerTwo, String newPassword})?>
  _promptRecoveryAnswers({
    required String questionOne,
    required String questionTwo,
  }) async {
    final formKey = GlobalKey<FormState>();
    final answerOneController = TextEditingController();
    final answerTwoController = TextEditingController();
    final newPasswordController = TextEditingController();
    var obscurePassword = true;

    final payload =
        await showDialog<
          ({String answerOne, String answerTwo, String newPassword})
        >(
          context: context,
          builder: (dialogContext) {
            return StatefulBuilder(
              builder: (dialogContext, setDialogState) {
                return AlertDialog(
                  title: const Text('Rispondi alle domande'),
                  content: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            questionOne,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: answerOneController,
                            decoration: const InputDecoration(
                              labelText: 'Risposta 1',
                            ),
                            validator: (value) {
                              final answer = value?.trim() ?? '';
                              return answer.isNotEmpty
                                  ? null
                                  : 'Inserisci una risposta.';
                            },
                          ),
                          const SizedBox(height: 12),
                          Text(
                            questionTwo,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: answerTwoController,
                            decoration: const InputDecoration(
                              labelText: 'Risposta 2',
                            ),
                            validator: (value) {
                              final answer = value?.trim() ?? '';
                              return answer.isNotEmpty
                                  ? null
                                  : 'Inserisci una risposta.';
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: newPasswordController,
                            obscureText: obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Nuova password',
                              helperText: 'Scegli la password che preferisci',
                              suffixIcon: IconButton(
                                tooltip: obscurePassword
                                    ? 'Mostra password'
                                    : 'Nascondi password',
                                onPressed: () => setDialogState(() {
                                  obscurePassword = !obscurePassword;
                                }),
                                icon: Icon(
                                  obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final password = value ?? '';
                              return password.trim().isNotEmpty
                                  ? null
                                  : 'Inserisci la nuova password.';
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Annulla'),
                    ),
                    FilledButton(
                      onPressed: () {
                        final isValid =
                            formKey.currentState?.validate() ?? false;
                        if (!isValid) {
                          return;
                        }

                        Navigator.of(dialogContext).pop((
                          answerOne: answerOneController.text.trim(),
                          answerTwo: answerTwoController.text.trim(),
                          newPassword: newPasswordController.text,
                        ));
                      },
                      child: const Text('Aggiorna password'),
                    ),
                  ],
                );
              },
            );
          },
        );

    answerOneController.dispose();
    answerTwoController.dispose();
    newPasswordController.dispose();
    return payload;
  }

  @override
  Future<void> _openPasswordRecoveryFlow() async {
    if (widget.accountService == null || _isRecoveringAccountPassword) {
      return;
    }

    final email = await _promptRecoveryEmail();
    if (email == null || email.trim().isEmpty) {
      return;
    }

    late final String questionOne;
    late final String questionTwo;
    setState(() {
      _isRecoveringAccountPassword = true;
    });

    try {
      final recoveryQuestions = await widget.accountService!
          .loadRecoveryQuestions(email: email);
      questionOne = recoveryQuestions.questionOne;
      questionTwo = recoveryQuestions.questionTwo;
      if (recoveryQuestions.locked) {
        final waitMinutes = recoveryQuestions.retryAfterMinutes;
        throw ApiException(
          waitMinutes == null
              ? 'Troppi tentativi. Riprova tra poco.'
              : 'Troppi tentativi. Riprova tra circa $waitMinutes minuti.',
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecoveringAccountPassword = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
      return;
    }

    setState(() {
      _isRecoveringAccountPassword = false;
    });

    final recoveryPayload = await _promptRecoveryAnswers(
      questionOne: questionOne,
      questionTwo: questionTwo,
    );
    if (recoveryPayload == null) {
      return;
    }

    setState(() {
      _isRecoveringAccountPassword = true;
    });
    try {
      await widget.accountService!.recoverPassword(
        email: email,
        answerOne: recoveryPayload.answerOne,
        answerTwo: recoveryPayload.answerTwo,
        newPassword: recoveryPayload.newPassword,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecoveringAccountPassword = false;
      });
      _accountEmailController.text = email;
      _accountPasswordController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password aggiornata. Ora puoi accedere con la nuova password.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isRecoveringAccountPassword = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }

  @override
  Future<void> _openRecoveryQuestionsSetupFlow() async {
    if (widget.accountService == null ||
        _accountSession == null ||
        _isConfiguringRecoveryQuestions) {
      return;
    }

    final formKey = GlobalKey<FormState>();
    final questionOneController = TextEditingController();
    final answerOneController = TextEditingController();
    final questionTwoController = TextEditingController();
    final answerTwoController = TextEditingController();

    final payload =
        await showDialog<
          ({
            String questionOne,
            String answerOne,
            String questionTwo,
            String answerTwo,
          })?
        >(
          context: context,
          builder: (dialogContext) {
            Widget suggestionWrap({required TextEditingController controller}) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recoveryQuestionSuggestions
                    .map(
                      (question) => ActionChip(
                        label: Text(question),
                        onPressed: () {
                          controller.text = question;
                        },
                      ),
                    )
                    .toList(growable: false),
              );
            }

            return AlertDialog(
              title: const Text('Metodi di recupero'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Imposta 2 domande di sicurezza: puoi scegliere dai suggerimenti o scriverne di personalizzate.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: questionOneController,
                        decoration: const InputDecoration(
                          labelText: 'Domanda 1',
                        ),
                        validator: (value) {
                          final question = value?.trim() ?? '';
                          return question.isNotEmpty
                              ? null
                              : 'Inserisci una domanda.';
                        },
                      ),
                      const SizedBox(height: 8),
                      suggestionWrap(controller: questionOneController),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: answerOneController,
                        decoration: const InputDecoration(
                          labelText: 'Risposta 1',
                        ),
                        validator: (value) {
                          final answer = value?.trim() ?? '';
                          return answer.isNotEmpty
                              ? null
                              : 'Inserisci una risposta.';
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: questionTwoController,
                        decoration: const InputDecoration(
                          labelText: 'Domanda 2',
                        ),
                        validator: (value) {
                          final question = value?.trim() ?? '';
                          return question.isNotEmpty
                              ? null
                              : 'Inserisci una domanda.';
                        },
                      ),
                      const SizedBox(height: 8),
                      suggestionWrap(controller: questionTwoController),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: answerTwoController,
                        decoration: const InputDecoration(
                          labelText: 'Risposta 2',
                        ),
                        validator: (value) {
                          final answer = value?.trim() ?? '';
                          return answer.isNotEmpty
                              ? null
                              : 'Inserisci una risposta.';
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: () {
                    final isValid = formKey.currentState?.validate() ?? false;
                    if (!isValid) {
                      return;
                    }

                    Navigator.of(dialogContext).pop((
                      questionOne: questionOneController.text.trim(),
                      answerOne: answerOneController.text.trim(),
                      questionTwo: questionTwoController.text.trim(),
                      answerTwo: answerTwoController.text.trim(),
                    ));
                  },
                  child: const Text('Salva domande'),
                ),
              ],
            );
          },
        );

    questionOneController.dispose();
    answerOneController.dispose();
    questionTwoController.dispose();
    answerTwoController.dispose();

    if (payload == null) {
      return;
    }

    setState(() {
      _isConfiguringRecoveryQuestions = true;
    });
    try {
      await widget.accountService!.configureRecoveryQuestions(
        session: _accountSession,
        questionOne: payload.questionOne,
        answerOne: payload.answerOne,
        questionTwo: payload.questionTwo,
        answerTwo: payload.answerTwo,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isConfiguringRecoveryQuestions = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Domande di recupero salvate. Ora puoi recuperare la password senza codice.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isConfiguringRecoveryQuestions = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }

  @override
  Future<void> _registerAccount() async {
    if (widget.accountService == null) {
      return;
    }

    final email = _accountEmailController.text.trim();
    final password = _accountPasswordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci email e password per registrarti.'),
        ),
      );
      return;
    }

    setState(() {
      _isAuthenticatingAccount = true;
    });

    try {
      _logDiagnostic(
        'account.register.start',
        details: <String, Object?>{'email': email},
      );
      final session = await widget.accountService!.register(
        email: email,
        password: password,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _accountSession = session;
        _isAuthenticatingAccount = false;
        _accountAuthMode = AccountAuthMode.login;
        _lastCloudBackupSucceeded = null;
        _lastCloudBackupFeedback = null;
      });
      _accountPasswordController.clear();
      unawaited(_refreshCloudBackupStatus(silent: true));
      _logDiagnostic(
        'account.register.ok',
        details: <String, Object?>{'email': session.user.email},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account creato. Da ora i dati vengono salvati anche nel cloud.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isAuthenticatingAccount = false;
      });
      _logDiagnostic(
        'account.register.error',
        details: <String, Object?>{'email': email, 'error': error.toString()},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }

  @override
  Future<void> _loginAccount() async {
    if (widget.accountService == null) {
      return;
    }

    final email = _accountEmailController.text.trim();
    final password = _accountPasswordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inserisci email e password per accedere.'),
        ),
      );
      return;
    }

    setState(() {
      _isAuthenticatingAccount = true;
    });

    try {
      _logDiagnostic(
        'account.login.start',
        details: <String, Object?>{'email': email},
      );
      final session = await widget.accountService!.login(
        email: email,
        password: password,
      );
      final backupStatus = await widget.accountService!.loadCloudBackupStatus(
        session: session,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _accountSession = session;
        _isAuthenticatingAccount = false;
        _accountAuthMode = AccountAuthMode.login;
        _hasCloudBackupAvailable = backupStatus.hasBackup;
        _lastCloudBackupAt = backupStatus.hasBackup
            ? backupStatus.updatedAt
            : null;
        _lastCloudBackupAttemptAt = null;
        _lastCloudBackupSucceeded = null;
        _lastCloudBackupFeedback = backupStatus.hasBackup
            ? 'Account attivo. Backup cloud trovato: puoi ripristinarlo quando vuoi.'
            : 'Account attivo. Nessun backup cloud trovato: usa "Backup ora" per salvarne uno.';
      });
      _accountPasswordController.clear();

      if (!mounted) {
        return;
      }

      _logDiagnostic(
        'account.login.ok',
        details: <String, Object?>{
          'email': session.user.email,
          'hasBackup': backupStatus.hasBackup,
          'updatedAt': backupStatus.updatedAt?.toIso8601String(),
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            backupStatus.hasBackup
                ? 'Accesso completato. Backup cloud disponibile: tocca "Ripristina dal cloud" se vuoi recuperarlo.'
                : 'Accesso completato. Nessun backup cloud trovato: puoi iniziare e fare "Backup ora".',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isAuthenticatingAccount = false;
      });
      _logDiagnostic(
        'account.login.error',
        details: <String, Object?>{'email': email, 'error': error.toString()},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }

  @override
  Future<void> _restoreCloudBackup() async {
    if (widget.accountService == null || _accountSession == null) {
      return;
    }
    if (!_hasCloudBackupAvailable) {
      _logDiagnostic(
        'cloud.restore.skipped',
        details: const <String, Object?>{'reason': 'no_backup_available'},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nessun backup cloud disponibile per questo account. Usa "Backup ora".',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isRestoringCloudBackup = true;
    });

    try {
      _logDiagnostic('cloud.restore.start');
      final restoreResult = await widget.accountService!.restoreFromCloud(
        session: _accountSession,
      );
      if (!mounted) {
        return;
      }

      if (restoreResult.bundle != null) {
        await widget.onAppearanceSettingsChanged(
          restoreResult.bundle!.appearanceSettings,
        );
        await _loadSnapshot(
          month: _selectedMonth,
          selectedDate: _selectedDate,
          forceReload: true,
        );
        await _loadWorkdaySessionForDate(_selectedDate);
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isRestoringCloudBackup = false;
        _hasCloudBackupAvailable = restoreResult.hasBackup;
        _lastCloudBackupAt = restoreResult.hasBackup
            ? (restoreResult.bundle?.updatedAt ?? _lastCloudBackupAt)
            : null;
        _lastCloudBackupSucceeded = restoreResult.hasBackup;
        _lastCloudBackupFeedback = restoreResult.hasBackup
            ? 'Ripristino completato dal backup cloud.'
            : 'Nessun backup cloud disponibile per questo account.';
      });
      unawaited(_refreshCloudBackupStatus(silent: true));
      _logDiagnostic(
        'cloud.restore.ok',
        details: <String, Object?>{
          'hasBackup': restoreResult.hasBackup,
          'updatedAt': restoreResult.bundle?.updatedAt?.toIso8601String(),
        },
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            restoreResult.hasBackup
                ? 'Backup cloud ripristinato.'
                : 'Nessun backup cloud disponibile per questo account.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (_isUnauthorizedApiError(error)) {
        _logDiagnostic(
          'cloud.restore.unauthorized',
          details: <String, Object?>{'error': error.toString()},
        );
        await _handleInvalidCloudSession(showFeedback: true);
        return;
      }

      setState(() {
        _isRestoringCloudBackup = false;
      });
      _logDiagnostic(
        'cloud.restore.error',
        details: <String, Object?>{'error': error.toString()},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }

  @override
  Future<void> _logoutAccount() async {
    if (widget.accountService == null) {
      return;
    }

    setState(() {
      _isAuthenticatingAccount = true;
    });

    try {
      await widget.accountService!.logout();
      if (!mounted) {
        return;
      }

      setState(() {
        _accountSession = null;
        _isAuthenticatingAccount = false;
        _accountAuthMode = AccountAuthMode.login;
        _hasCloudBackupAvailable = false;
        _lastCloudBackupAt = null;
        _lastCloudBackupAttemptAt = null;
        _lastCloudBackupSucceeded = null;
        _lastCloudBackupFeedback = null;
        _isLoadingCloudBackupStatus = false;
      });
      _logDiagnostic('account.logout.ok');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Backup cloud disattivato. I dati restano su questo dispositivo.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isAuthenticatingAccount = false;
      });
      _logDiagnostic(
        'account.logout.error',
        details: <String, Object?>{'error': error.toString()},
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_humanizeError(error))));
    }
  }
}
