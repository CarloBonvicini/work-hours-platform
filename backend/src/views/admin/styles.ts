// Foglio di stile della dashboard admin.

export const adminStyles = `
      :root {
        --bg: #1e1e1e;
        --bg-card: rgba(37, 37, 38, 0.96);
        --bg-soft: rgba(22, 26, 35, 0.74);
        --bg-input: #1f1f1f;
        --line: #3f3f46;
        --line-strong: #4c4c52;
        --ink: #d4d4d4;
        --muted: #9da3a9;
        --accent: #0e639c;
        --accent-hover: #1177bb;
        --success: #73c991;
        --success-soft: rgba(115, 201, 145, 0.14);
        --warning: #f2cc60;
        --warning-soft: rgba(242, 204, 96, 0.14);
        --danger: #f48771;
        --danger-soft: rgba(244, 135, 113, 0.14);
        --info: #75beff;
        --shadow: 0 18px 40px rgba(0, 0, 0, 0.28);
      }
      * { box-sizing: border-box; }
      body {
        margin: 0;
        min-height: 100vh;
        overflow-x: hidden;
        color: var(--ink);
        font-family: "Segoe UI", "IBM Plex Sans", sans-serif;
        background-color: var(--bg);
        background:
          linear-gradient(180deg, rgba(14, 99, 156, 0.12), transparent 220px),
          radial-gradient(circle at top right, rgba(14, 99, 156, 0.14), transparent 32%),
          linear-gradient(180deg, #181818 0%, var(--bg) 100%);
        background-repeat: no-repeat;
        background-size: 100% 220px, 100% 100%, 100% 100%;
        background-attachment: fixed;
      }
      .shell { max-width: 1440px; margin: 0 auto; padding: 32px 20px 64px; }
      .hero { text-align: center; margin-bottom: 26px; }
      .hero-actions { display: flex; justify-content: flex-end; gap: 10px; margin-bottom: 12px; }
      .brand-lockup { position: relative; width: min(100%, 220px); height: 88px; margin: 0 auto 10px; }
      .brand-mark { position: absolute; inset: 0; margin: auto; width: 108px; height: 72px; border-radius: 22px; border: 1px solid rgba(117,190,255,0.24); background: linear-gradient(135deg, rgba(117,190,255,0.16), rgba(14,99,156,0.72)); box-shadow: inset 0 1px 0 rgba(255,255,255,0.08), 0 14px 30px rgba(0,0,0,0.28); }
      .brand-mark::before, .brand-mark::after { content: ""; position: absolute; inset: 0; margin: auto; }
      .brand-mark::before { width: 30px; height: 30px; border-radius: 10px; border: 2px solid rgba(255,255,255,0.74); transform: translateX(-18px) rotate(10deg); }
      .brand-mark::after { width: 10px; height: 34px; border-radius: 999px; background: rgba(255,255,255,0.84); transform: translateX(18px); }
      .brand-mark-main::before { box-shadow: 22px 0 0 rgba(255,255,255,0.22); }
      .brand-mark-glow { opacity: 0.68; filter: blur(18px) saturate(1.16); transform: scale(1.08); }
      .ghost-link, button, input, textarea, select, code {
        font: inherit;
      }
      .ghost-link {
        display: inline-flex; align-items: center; justify-content: center; padding: 8px 12px; border-radius: 8px;
        border: 1px solid var(--line); background: rgba(22, 26, 35, 0.56); color: #c4e0f7; text-decoration: none; font-size: 12px; font-weight: 600; letter-spacing: 0.02em;
        transition: border-color 140ms ease, color 140ms ease, background 140ms ease;
      }
      .ghost-link:hover { border-color: rgba(117,190,255,0.72); background: rgba(14,99,156,0.18); color: #e9f6ff; }
      .toolbar-quick-link { font-size: 13px; font-weight: 700; }
      .eyebrow { margin: 0 0 10px; color: var(--info); text-transform: uppercase; letter-spacing: 0.18em; font-size: 12px; }
      h1,h2,h3,h4 { margin: 0 0 12px; color: #fff; font-family: "Segoe UI Semibold", "Segoe UI", sans-serif; }
      h1 { font-size: clamp(2.2rem, 4vw, 3rem); }
      p { margin: 0; }
      .lede, .muted { color: var(--muted); line-height: 1.45; overflow-wrap: anywhere; }
      .panel, .card, .stat { background: var(--bg-card); border: 1px solid var(--line); border-radius: 14px; box-shadow: var(--shadow); min-width: 0; max-width: 100%; }
      .panel { padding: 20px; margin-bottom: 18px; }
      .auth-stage { display: grid; justify-items: center; padding: 0; border: 0; background: transparent; box-shadow: none; }
      .auth-shell { width: min(100%, 920px); padding: 20px; border-color: rgba(117,190,255,0.24); background: rgba(22,26,35,0.62); backdrop-filter: blur(16px); box-shadow: 0 22px 50px rgba(0,0,0,0.4), 0 0 0 1px rgba(117,190,255,0.14), 0 0 34px rgba(14,99,156,0.22); }
      .auth-view { display: grid; gap: 14px; }
      .auth-cta { color: var(--muted); font-size: 14px; }
      .auth-grid { display: grid; gap: 14px; grid-template-columns: minmax(0, 460px); justify-content: center; }
      .auth-card { align-content: start; }
      .auth-card h3 { margin-bottom: 6px; }
      .auth-switch { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; color: var(--muted); font-size: 13px; }
      .link-button {
        min-height: 0;
        padding: 0;
        border: 0;
        background: transparent;
        color: var(--info);
        font-weight: 700;
      }
      .link-button:hover { background: transparent; color: #bfe2ff; }
      .pill { display: inline-flex; align-items: center; gap: 6px; width: fit-content; border-radius: 999px; padding: 5px 10px; font-size: 12px; font-weight: 700; }
      .pill.info { background: rgba(117, 190, 255, 0.12); color: var(--info); }
      .pill.warning { background: var(--warning-soft); color: var(--warning); }
      .pill.success { background: var(--success-soft); color: var(--success); }
      .hidden { display: none !important; }
      .toolbar { display: flex; align-items: center; justify-content: space-between; gap: 12px; }
      .console-toolbar { margin-bottom: 6px; align-items: flex-start; }
      .toolbar-actions { display: flex; gap: 10px; flex-wrap: wrap; justify-content: flex-end; }
      button {
        border: 1px solid var(--line); border-radius: 8px; background: var(--bg-input);
        color: var(--ink); min-height: 42px; padding: 0 14px; cursor: pointer;
        transition: border-color 140ms ease, box-shadow 140ms ease, background 140ms ease, transform 140ms ease;
      }
      button.primary { background: linear-gradient(180deg, var(--accent-hover), var(--accent)); border-color: rgba(117,190,255,0.42); color: white; }
      button:hover { border-color: var(--line-strong); background: rgba(255,255,255,0.06); }
      input, textarea, select {
        width: 100%; border-radius: 8px; border: 1px solid var(--line); background: var(--bg-input); color: var(--ink); padding: 12px 13px;
      }
      textarea { min-height: 140px; resize: vertical; }
      form { display: grid; gap: 12px; }
      label { display: grid; gap: 7px; color: var(--muted); font-size: 13px; }
      code { display: inline-block; padding: 2px 6px; border-radius: 6px; background: rgba(255,255,255,0.06); color: #f0f3f6; }
      .status { border-radius: 10px; padding: 12px 14px; border: 1px solid transparent; font-weight: 600; }
      .status.info { background: rgba(117, 190, 255, 0.1); color: var(--info); }
      .status.error { background: var(--danger-soft); color: var(--danger); }
      .status.success { background: var(--success-soft); color: var(--success); }
      .console-section { display: grid; gap: 14px; margin-top: 18px; }
      .section-heading { display: flex; align-items: flex-start; justify-content: space-between; gap: 12px; }
      .section-heading-copy { display: grid; gap: 4px; }
      .section-heading h3 { margin-bottom: 4px; }
      .section-heading p { margin: 0; color: var(--muted); font-size: 13px; }
      .stats { display: grid; gap: 16px; grid-template-columns: repeat(auto-fit, minmax(170px, 1fr)); }
      .stat { padding: 16px; background: linear-gradient(180deg, rgba(37,37,38,0.96), rgba(28,28,31,0.96)); }
      .stat.tone-info { border-color: rgba(117,190,255,0.2); }
      .stat.tone-warning { border-color: rgba(242,204,96,0.2); }
      .stat.tone-success { border-color: rgba(115,201,145,0.2); }
      .stat-label { color: var(--muted); font-size: 12px; text-transform: uppercase; letter-spacing: 0.08em; }
      .stat-value { margin-top: 10px; font-size: 30px; font-weight: 700; color: #fff; }
      .stat-note { margin-top: 8px; color: var(--muted); font-size: 13px; line-height: 1.45; }
      .admin-console-layout { display: grid; gap: 16px; grid-template-columns: minmax(240px, 280px) minmax(0, 1fr); align-items: start; }
      .workspace-nav { display: grid; gap: 12px; padding: 14px; }
      .workspace-nav h4 { margin: 0; color: var(--muted); font-size: 12px; letter-spacing: 0.12em; text-transform: uppercase; }
      .workspace-stack { display: grid; gap: 12px; }
      .workspace-card { display: grid; gap: 10px; border: 1px solid var(--line); border-radius: 10px; background: rgba(22,22,24,0.75); padding: 12px; }
      .mini-label { color: #89929d; font-size: 11px; letter-spacing: 0.08em; text-transform: uppercase; }
      .workspace-value { color: #fff; font-size: 16px; font-weight: 700; }
      .metric-row { display: flex; align-items: center; justify-content: space-between; gap: 10px; color: #d8dde4; }
      .metric-row + .metric-row { padding-top: 8px; border-top: 1px solid rgba(255,255,255,0.06); }
      .metric-row strong { color: #fff; }
      .quick-link-grid { display: grid; gap: 8px; }
      .admin-content-grid { display: grid; gap: 16px; }
      .ticket-workspace { display: grid; gap: 16px; grid-template-columns: minmax(300px, 360px) minmax(0, 1fr); align-items: start; }
      .ticket-list { display: grid; gap: 10px; max-height: 72vh; overflow: auto; padding-right: 4px; }
      .ticket-card { border-radius: 12px; border: 1px solid var(--line); background: var(--bg-soft); padding: 14px; cursor: pointer; transition: border-color 140ms ease, background 140ms ease, transform 140ms ease; }
      .ticket-card:hover { border-color: rgba(117,190,255,0.34); background: rgba(26,30,38,0.9); transform: translateY(-1px); }
      .ticket-card.is-active { border-color: rgba(117,190,255,0.72); box-shadow: inset 0 0 0 1px rgba(117,190,255,0.24), 0 14px 28px rgba(0,0,0,0.2); }
      .ticket-card-head, .ticket-badges, .ticket-card-summary, .reply-meta, .reply-actions { display: flex; gap: 8px; flex-wrap: wrap; }
      .ticket-card-head { align-items: flex-start; justify-content: space-between; }
      .ticket-card-head { justify-content: space-between; }
      .ticket-card-summary { margin-top: 10px; color: var(--muted); font-size: 12px; }
      .badge { display: inline-flex; align-items: center; border-radius: 999px; padding: 4px 10px; font-size: 12px; font-weight: 700; }
      .badge.status-new { background: var(--warning-soft); color: var(--warning); }
      .badge.status-in_progress { background: rgba(117, 190, 255, 0.12); color: var(--info); }
      .badge.status-answered { background: var(--success-soft); color: var(--success); }
      .badge.status-closed { background: rgba(255,255,255,0.08); color: var(--muted); }
      .badge.category-bug { background: var(--danger-soft); color: var(--danger); }
      .badge.category-feature { background: rgba(117, 190, 255, 0.12); color: var(--info); }
      .badge.category-support { background: rgba(255,255,255,0.08); color: #d9e2ec; }
      .ticket-title { margin: 6px 0 4px; font-size: 16px; font-weight: 700; }
      .ticket-meta, .field-label { color: var(--muted); font-size: 12px; }
      .field-label { text-transform: uppercase; letter-spacing: 0.08em; }
      .detail-shell { display: grid; gap: 18px; }
      .detail-title { margin: 6px 0; }
      .thread { display: grid; gap: 12px; }
      .message-card { border-radius: 12px; border: 1px solid var(--line); padding: 14px; background: rgba(255,255,255,0.02); }
      .message-card.reply { background: rgba(117, 190, 255, 0.06); border-color: rgba(117, 190, 255, 0.22); }
      .attachment-gallery { display: grid; gap: 12px; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); margin-top: 12px; }
      .attachment-card { display: grid; gap: 10px; border-radius: 12px; border: 1px solid var(--line); background: rgba(255,255,255,0.03); padding: 12px; text-decoration: none; color: inherit; }
      .attachment-preview { display: block; width: 100%; aspect-ratio: 4 / 3; object-fit: cover; border-radius: 10px; border: 1px solid rgba(255,255,255,0.08); background: rgba(0,0,0,0.16); }
      .attachment-preview.placeholder { display: grid; place-items: center; color: var(--muted); font-size: 12px; }
      .attachment-audio-player { width: 100%; }
      .attachment-name { font-size: 13px; font-weight: 700; color: #fff; word-break: break-word; }
      .attachment-meta { color: var(--muted); font-size: 12px; }
      .attachment-link { color: var(--info); font-size: 12px; text-decoration: none; font-weight: 700; }
      .detail-grid { display: grid; gap: 12px; grid-template-columns: repeat(2, minmax(0, 1fr)); }
      .field { display: grid; gap: 6px; }
      .reply-form { display: grid; gap: 12px; }
      .reply-actions { justify-content: flex-end; }
      .empty-state { border-radius: 12px; border: 1px dashed var(--line); padding: 18px; color: var(--muted); text-align: center; }
      .user-list { display: grid; gap: 10px; }
      .user-row { display: grid; gap: 10px; grid-template-columns: minmax(0, 1fr) auto; align-items: center; border: 1px solid var(--line); border-radius: 12px; background: var(--bg-soft); padding: 14px; }
      .user-row-main { display: grid; gap: 6px; min-width: 0; }
      .user-row-email { color: #fff; font-weight: 700; overflow-wrap: anywhere; }
      .user-row-meta { display: flex; gap: 8px; flex-wrap: wrap; color: var(--muted); font-size: 12px; }
      .user-actions { display: flex; gap: 8px; flex-wrap: wrap; justify-content: flex-end; }
      @media (max-width: 1120px) { .ticket-workspace { grid-template-columns: 1fr; } }
      @media (max-width: 980px) { .admin-console-layout { grid-template-columns: 1fr; } }
      @media (max-width: 720px) { .shell { padding: 20px 14px 40px; } .hero-actions, .toolbar, .section-heading, .user-row { flex-direction: column; align-items: stretch; } .toolbar-actions, .user-actions { justify-content: flex-start; } .stats, .detail-grid, .auth-grid { grid-template-columns: 1fr; } .user-row { display: grid; grid-template-columns: 1fr; } }
`;
