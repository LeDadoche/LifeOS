const AgendaModule = (function(){
        // ======= CONFIG / CONSTANTES =======
        const ORG_PREFIX = 'MultiappOrg · ';          // Prefix des agendas Google
        const GCAL_SCOPES = 'openid email profile https://www.googleapis.com/auth/calendar';
        const GCAL_API    = 'https://www.googleapis.com/calendar/v3';

        // LocalStorage
        const LS_EVENTS       = 'agenda:events:multiorg:v1';    // [{id, cal, date, title, gid?}]
        const LS_VISIBLE      = 'agenda:visible:multiorg:v1';   // [calKey...]
        const LS_SELECTED_ORG = 'agenda:selectedOrgs:v1';       // [orgName...]
        const LS_G_TOKEN      = 'agenda:gcal:token';
        const LS_G_GRANTED    = 'agenda:gcal:granted';

        // ======= ETAT UI / DONNEES =======
        let container, grid, monthLbl, btnPrev, btnNext, btnToday;
        let whoSel, filtersWrap, quickForm, quickCal, quickTitle, quickAdd, dayTitle, dayList, dayEmpty;

        // Google UI
        let statusEl, btnConnect, btnLogout;
        let orgNameInp, orgMembersInp, orgCreateBtn, orgCreatePersonals, orgSendInvites, orgRefreshBtn;
        let orgOwnedList, orgSharedList, orgImportBtn, orgImportPrimaryBtn;

        // Etat calendrier
        let currentMonth = new Date(); currentMonth.setDate(1);
        let selectedDay = null;
        let events = [];                 // évènements locaux (affichage)
        let visible = new Set();         // calKeys visibles

        // Multi-organisations (détectées sur Google)
        let orgsOwned = [];              // [{name, generalId, members:[{email, calId}], color}]
        let orgsShared = [];             // idem
        let selectedOrgs = new Set();    // noms d'org cochées
        let accessToken = null;

      // ======= HELPERS GÉNÉRIQUES =======
      function pad2(n){ return String(n).padStart(2,'0'); }
      function ymd(d){ return `${d.getFullYear()}-${pad2(d.getMonth()+1)}-${pad2(d.getDate())}`; }
      function todayYMD(){ return ymd(new Date()); }
      function parseYMD(s){ const m = String(s||'').match(/^(\d{4})-(\d{2})-(\d{2})$/); return m? new Date(+m[1], +m[2]-1, +m[3]) : null; }
      function uid(){ return Date.now().toString(36)+Math.random().toString(36).slice(2,7); }
      function esc(s){ return String(s).replace(/[&<>"']/g, m=>({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;' }[m])); }
      function splitEmails(txt){
        return String(txt||'')
        .split(/[\s,;]+/g)
        .map(s=>s.trim())
        .filter(s=>/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(s));
      }
          
      // ======= PERSISTENCE =======
      function loadAll(){
        try{ events = JSON.parse(localStorage.getItem(LS_EVENTS)||'[]'); }catch{ events=[]; }
        if (!Array.isArray(events)) events=[];
        try{ const v = JSON.parse(localStorage.getItem(LS_VISIBLE)||'null'); if (Array.isArray(v)) visible = new Set(v); }catch{}
        try{ const s = JSON.parse(localStorage.getItem(LS_SELECTED_ORG)||'null'); if (Array.isArray(s)) selectedOrgs = new Set(s); }catch{}
      }
      function saveEvents(){ try{ localStorage.setItem(LS_EVENTS, JSON.stringify(events)); }catch{} }
      function saveVisible(){ try{ localStorage.setItem(LS_VISIBLE, JSON.stringify(Array.from(visible))); }catch{} }
      function saveSelectedOrgs(){ try{ localStorage.setItem(LS_SELECTED_ORG, JSON.stringify(Array.from(selectedOrgs))); }catch{} }

      // ======= PERSISTENCE ORG / INVITES (local, safe helpers) =======
      const LS_ORGS = 'agenda:orgs:v1';                    // optional cached org metadata
      const LS_INVITES = 'agenda:org:invites:v1';          // queued invites (pending)
      const LS_INVITE_NOTIFS = 'agenda:org:invite-notifs:v1'; // local notifications for invite responses

      function loadOrgsLS(){ try{ return JSON.parse(localStorage.getItem(LS_ORGS)||'[]'); }catch{ return []; } }
      function saveOrgsLS(arr){ try{ localStorage.setItem(LS_ORGS, JSON.stringify(arr||[])); }catch{} }

      function loadInvitesLS(){ try{ return JSON.parse(localStorage.getItem(LS_INVITES)||'[]'); }catch{ return []; } }
      function saveInvitesLS(arr){ try{ localStorage.setItem(LS_INVITES, JSON.stringify(arr||[])); }catch{} }

      function loadInviteNotifs(){ try{ return JSON.parse(localStorage.getItem(LS_INVITE_NOTIFS)||'[]'); }catch{ return []; } }
      function saveInviteNotifs(arr){ try{ localStorage.setItem(LS_INVITE_NOTIFS, JSON.stringify(arr||[])); }catch{} }

      function pushInviteNotif(n){
        try{
          const list = loadInviteNotifs();
          list.unshift(Object.assign({ id: uid(), createdAt: Date.now() }, n));
          saveInviteNotifs(list);
          // notify UI if available
          if (typeof renderOrgLists === 'function') renderOrgLists();
          if (typeof renderInviteNotifs === 'function') renderInviteNotifs();
        }catch{};
      }

      /**
       * Queue invites locally for an organisation.
       * - orgName: string
       * - emails: string | string[] (comma/space separated allowed)
       * - opts: { note?:string }
       * This function does NOT perform Google ACL operations automatically.
       */
      window.__agenda_sendInvitesForOrg = async function(orgName, emails, opts){
        try{
          const raw = Array.isArray(emails) ? emails.join(' ') : String(emails||'');
          const list = splitEmails(raw);
          if (!orgName || !list.length) return { ok:false, reason:'missing' };
          const me = (typeof whoAmI === 'function') ? (await whoAmI().catch(()=>null)) : null;
          const from = me && me.email ? me.email : null;
          const stored = loadInvitesLS();
          for (const to of list){
            const it = { id: uid(), org: orgName, email: to, from: from, status: 'pending', note: opts?.note || '', createdAt: Date.now() };
            stored.push(it);
            // local notification for the inviter (visible in UI)
            pushInviteNotif({ org: orgName, email: to, from, status: 'pending' });
          }
          saveInvitesLS(stored);
          // trigger a UI refresh + optional background scan
          if (typeof scanOrganizations === 'function') scanOrganizations().catch(()=>{});
          if (typeof renderInviteNotifs === 'function') renderInviteNotifs();
          return { ok:true, queued: list.length };
        }catch(e){ return { ok:false, reason: e && e.message || String(e) }; }
      };

      // ======= INVITES UI (render + handlers) =======
      function renderInviteNotifs(){
        try{
          const host = document.getElementById('org-invite-notifs');
          const listRoot = document.getElementById('org-invite-list');
          if (!host || !listRoot) return;
          const list = loadInviteNotifs();
          if (!list || !list.length){ host.textContent = 'Aucune invitation.'; listRoot.innerHTML = ''; return; }
          host.textContent = list.length + ' notification(s)';
          listRoot.innerHTML = '';
          list.forEach(item => {
            const row = document.createElement('div');
            row.className = 'row';
            row.style.cssText = 'display:flex; align-items:center; justify-content:space-between; gap:8px; padding:6px 0;';
            const left = document.createElement('div'); left.style.cssText='display:flex; gap:8px; align-items:center; min-width:0;';
            left.innerHTML = `<div style="font-weight:600; overflow:hidden; text-overflow:ellipsis;">${esc(item.org || '')}</div><div class="muted" style="font-size:.9rem;">${esc(item.email||'')}</div>`;
            const right = document.createElement('div');
            const accept = document.createElement('button'); accept.type='button'; accept.className='btn primary'; accept.textContent='Accepter';
            const decline = document.createElement('button'); decline.type='button'; decline.className='btn ghost'; decline.textContent='Refuser';
            const realSend = document.createElement('button'); realSend.type='button'; realSend.className='btn'; realSend.textContent='Envoyer réel';

            accept.addEventListener('click', async ()=>{
              // Accept locally: mark visible/select org
              // add to selectedOrgs and save
              if (item.org) selectedOrgs.add(item.org);
              saveSelectedOrgs();
              // remove this notif
              const cur = loadInviteNotifs().filter(n=>n.id!==item.id);
              saveInviteNotifs(cur);
              // optionally accept by creating personal calend or other (not automated)
              renderOrgLists(); renderInviteNotifs(); buildFilters(); renderGrid(); renderDayPanel();
            });

            decline.addEventListener('click', ()=>{
              const cur = loadInviteNotifs().filter(n=>n.id!==item.id);
              saveInviteNotifs(cur);
              renderInviteNotifs();
            });

            realSend.addEventListener('click', async ()=>{
              // If connected, offer to perform real ACL send via inviteMembersToOrg
              if (!loadSavedToken() && !accessToken){ alert('Connecte-toi à Google pour envoyer des invitations réelles.'); return; }
              const ok = confirm('Envoyer une invitation réelle via Google Calendar (enverra un e-mail) ?');
              if (!ok) return;
              try{
                await ensureToken(true);
                // inviteMembersToOrg expects orgName field in orgNameInp, and emails in orgMembersInp
                orgNameInp.value = item.org || '';
                orgMembersInp.value = item.email || '';
                await inviteMembersToOrg();
                // mark notif handled
                const cur = loadInviteNotifs().filter(n=>n.id!==item.id);
                saveInviteNotifs(cur);
                renderInviteNotifs();
              }catch(e){ alert(e && e.message ? e.message : e); }
            });

            right.appendChild(accept); right.appendChild(decline); right.appendChild(realSend);
            row.appendChild(left); row.appendChild(right);
            listRoot.appendChild(row);
          });
        }catch(e){}
      }

      // ======= GOOGLE (auth + stockage token) =======
      function setStatus(msg){ if (statusEl) statusEl.textContent = msg; }
      function getClientId(){
        const fromMeta = document.querySelector('meta[name="google-client-id"]')?.content;
        if (fromMeta && !/REPLACE_WITH/i.test(fromMeta)) return fromMeta.trim();
        if (typeof window.GOOGLE_CLIENT_ID === 'string' && window.GOOGLE_CLIENT_ID) return window.GOOGLE_CLIENT_ID;
        return null;
      }
      function loadGisScript(){
        return new Promise((resolve, reject)=>{
          if (window.google?.accounts?.oauth2) return resolve();
          const s=document.createElement('script');
          s.src='https://accounts.google.com/gsi/client'; s.async=true; s.defer=true;
          s.onload=()=> resolve();
          s.onerror=()=> reject(new Error('Impossible de charger Google Identity Services'));
          document.head.appendChild(s);
        });
      }
      function saveToken(access_token, expires_in){
        try{
          const ttl = Math.max(60, Number(expires_in||3600)) - 30;
          const expires_at = Date.now() + ttl*1000;
          localStorage.setItem(LS_G_TOKEN, JSON.stringify({ access_token, expires_at }));
        }catch{}
      }
      function loadSavedToken(){
        try{
          const obj = JSON.parse(localStorage.getItem(LS_G_TOKEN)||'null');
          if (!obj || !obj.access_token || !obj.expires_at) return null;
          if (obj.expires_at <= Date.now()) return null;
          accessToken = obj.access_token;
          return accessToken;
        }catch{ return null; }
      }
      function clearSavedToken(){ try{ localStorage.removeItem(LS_G_TOKEN); }catch{} accessToken=null; }
      function markGranted(flag){ try{ localStorage.setItem(LS_G_GRANTED, flag?'1':'0'); }catch{} }
      function hasGrant(){ try{ return localStorage.getItem(LS_G_GRANTED)==='1'; }catch{ return false; } }

      let tokenClient = null;
      let tokenPromise = null;

      async function ensureToken(interactive){
        if (accessToken) return accessToken;
        const saved = loadSavedToken(); if (saved) return saved;
        const clientId = getClientId();
        if (!clientId){ alert('Client ID Google manquant (<meta name="google-client-id">)'); throw new Error('GOOGLE_CLIENT_ID manquant'); }
        await loadGisScript();
        tokenPromise = new Promise((resolve,reject)=>{
          try{
            if (!tokenClient){
              tokenClient = google.accounts.oauth2.initTokenClient({
                client_id: clientId,
                scope: GCAL_SCOPES,
                ux_mode: 'popup',
                callback: (resp)=>{
                  tokenPromise = null;
                  if (resp && resp.access_token){
                    accessToken = resp.access_token;
                    saveToken(resp.access_token, resp.expires_in);
                    markGranted(true);
                    resolve(accessToken);
                  } else reject(new Error('Aucun jeton reçu'));
                }
              });
            }
            tokenClient.requestAccessToken({ prompt: interactive ? 'consent' : '' });
          }catch(e){ tokenPromise=null; reject(e); }
        });
        return tokenPromise;
      }

      async function whoAmI(){
        try{
          if (!loadSavedToken() && !accessToken) return null;
          const r = await fetch('https://www.googleapis.com/oauth2/v3/userinfo', { headers:{ Authorization:`Bearer ${accessToken}` }});
          if (!r.ok) return null;
          return r.json();
        }catch{ return null; }
      }

      async function gfetch(path, { method='GET', query=null, body=null, interactive=false } = {}){
        // ⬇️ Ne force pas de popup par défaut ; les handlers UI appellent déjà ensureToken(true)
        await ensureToken(interactive);

        const url = new URL(GCAL_API + path);
        if (query) Object.entries(query).forEach(([k, v]) => url.searchParams.set(k, v));

        const resp = await fetch(url.toString(), {
          method,
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json'
          },
          body: body ? JSON.stringify(body) : null
        });

        if (!resp.ok) {
          let msg = `HTTP ${resp.status}`;
          try { const j = await resp.json(); if (j.error && j.error.message) msg += ` — ${j.error.message}`; } catch {}
          throw new Error(msg);
        }
        return resp.json();
      }

      function disconnectGoogle(){
        clearSavedToken(); markGranted(false);
        setStatus('Non connecté.');
        updateGoogleButtons();
      }

      async function silentReconnect(){
        if (loadSavedToken()){
          const me = await whoAmI();
          if (me && me.email){
            setStatus('Connecté : ' + me.email);
            updateGoogleButtons();
            return;
          }
        }
  // Do NOT call ensureToken(false) here: that can trigger a popup in some browsers
  // instead, rely only on an already saved/valid token. If no saved token, remain disconnected.
        setStatus('Non connecté.');
        updateGoogleButtons();
      }

      function updateGoogleButtons(){
        const connected = !!(loadSavedToken() || accessToken);

        // Affiche/masque Connexion/Déconnexion
        if (btnConnect) btnConnect.style.display = connected ? 'none' : '';
        if (btnLogout)  btnLogout.style.display  = connected ? '' : 'none';

        // Les actions d’orga visibles seulement si connecté
        const showOrgActions = connected ? '' : 'none';
        if (orgCreateBtn)         orgCreateBtn.style.display        = showOrgActions;
        if (orgRefreshBtn)        orgRefreshBtn.style.display       = showOrgActions;
        if (orgImportBtn)         orgImportBtn.style.display        = showOrgActions;
        if (orgImportPrimaryBtn)  orgImportPrimaryBtn.style.display = showOrgActions;

        // Désactive intelligemment les imports selon la sélection
        const selCount = (typeof selectedOrgs !== 'undefined' && selectedOrgs) ? selectedOrgs.size : 0;
        if (orgImportBtn)         orgImportBtn.disabled        = !connected || selCount === 0;
        if (orgImportPrimaryBtn)  orgImportPrimaryBtn.disabled = !connected || selCount !== 1;

        // Bouton "Inviter les membres" = grisé si pas connecté ou champ vide
        if (typeof window.updateInviteBtnState === 'function') window.updateInviteBtnState();
      }

      // ======= ORGANISATIONS (détection, création, invitations) =======
      function parseOrgFromSummary(summary){
        // "MultiappOrg · Nom · General"
        // "MultiappOrg · Nom · Member · email@..."
        const s = String(summary||'');
        if (s.indexOf(ORG_PREFIX)!==0) return null;
        const parts = s.slice(ORG_PREFIX.length).split('·').map(p=>p.trim());
        if (!parts.length) return null;
        const name = parts[0];
        if (parts.length>=2 && /^general$/i.test(parts[1])) return { name, type:'general' };
        if (parts.length>=3 && /^member$/i.test(parts[1]))  return { name, type:'member', email: parts.slice(2).join(' · ') };
        return { name, type:'unknown' };
      }

      async function scanOrganizations(){
        const list = await gfetch('/users/me/calendarList', { query:{ maxResults:'250' }});
        const items = Array.isArray(list.items) ? list.items : [];
        const groups = new Map(); // name -> {name, generalId, members:[], owner:bool}

        for (const c of items){
          const meta = parseOrgFromSummary(c.summary);
          if (!meta) continue;
          if (!groups.has(meta.name)) groups.set(meta.name, { name: meta.name, generalId: null, members: [], owner: false });
          const g = groups.get(meta.name);
          const role = String(c.accessRole||'').toLowerCase();
          if (role === 'owner') g.owner = true;

          if (meta.type === 'general') g.generalId = c.id;
          else if (meta.type === 'member' && meta.email) g.members.push({ email: meta.email, calId: c.id });
        }

        orgsOwned  = Array.from(groups.values()).filter(o => o.owner);
        orgsShared = Array.from(groups.values()).filter(o => !o.owner);

        renderOrgLists();
      }

      function renderOrgLists(){
        function renderList(root, data, section){
          root.innerHTML = '';
          if (!data.length){
            root.innerHTML = '<div class="muted">Aucune</div>';
            return;
          }
          data.forEach(o=>{
            const id = 'orgchk-'+section+'-'+o.name.replace(/\s+/g,'_');
            const wrap = document.createElement('div');
            wrap.className = 'row';
            wrap.style.cssText = 'display:flex; align-items:center; justify-content:space-between; gap:8px; padding:6px 0;';
            const left = document.createElement('div');
            left.style.cssText='display:flex; align-items:center; gap:8px;';
            const cb = document.createElement('input');
            cb.type='checkbox'; cb.id=id; cb.checked = selectedOrgs.has(o.name);
            cb.addEventListener('change', ()=>{
              if (cb.checked) selectedOrgs.add(o.name); else selectedOrgs.delete(o.name);
              saveSelectedOrgs(); buildFilters(); renderGrid(); renderDayPanel();
            });
            const lbl = document.createElement('label');
            lbl.setAttribute('for', id);
            lbl.innerHTML = `<b>${esc(o.name)}</b> &nbsp;<span class="muted">${o.members.length} membre(s)</span>`;
            left.appendChild(cb); left.appendChild(lbl);
            wrap.appendChild(left);

            if (o.owner){
              const right = document.createElement('div');
              const btn = document.createElement('button');
              btn.className='btn ghost';
              btn.textContent = 'Inviter des membres';
              btn.title = 'Ajoute des membres à cette organisation';
              btn.addEventListener('click', ()=>{
                orgNameInp.value = o.name;
                orgMembersInp.focus();
              });
              right.appendChild(btn);
              wrap.appendChild(right);
            }

            root.appendChild(wrap);
          });
        }

        renderList(orgOwnedList, orgsOwned, 'owned');
        renderList(orgSharedList, orgsShared, 'shared');
        updateGoogleButtons();
        buildFilters();
      }

      // Crée une org (Général + (option) perso par membre) et partage
      async function createOrganization(){
        const name = orgNameInp.value.trim();
        if (!name){ alert('Indique un nom d’organisation.'); return; }
        const members = splitEmails(orgMembersInp.value);
        const createPersonals = !!orgCreatePersonals.checked;
        const sendInv = !!orgSendInvites.checked;

        setStatus('Création de l’organisation…');

        // 1) Général
        const general = await gfetch('/calendars', { method:'POST', body:{ summary: ORG_PREFIX + name + ' · General' }});
        const generalId = general.id;
        await gfetch('/users/me/calendarList', { method:'POST', body:{ id: generalId } }).catch(()=>{});

        // 2) ACL du Général (tous membres = writer)
        for (const m of members){
          await gfetch(`/calendars/${encodeURIComponent(generalId)}/acl`, {
            method:'POST', query:{ sendNotifications: sendInv?'true':'false' },
            body:{ role:'writer', scope:{ type:'user', value:m } }
          }).catch(()=>{});
        }

        // 3) Perso (optionnel)
        if (createPersonals){
          for (const m of members){
            const cal = await gfetch('/calendars', { method:'POST', body:{ summary: ORG_PREFIX + name + ' · Member · ' + m }});
            await gfetch('/users/me/calendarList', { method:'POST', body:{ id: cal.id } }).catch(()=>{});
            await gfetch(`/calendars/${encodeURIComponent(cal.id)}/acl`, {
              method:'POST', query:{ sendNotifications: sendInv?'true':'false' },
              body:{ role:'writer', scope:{ type:'user', value:m } }
            }).catch(()=>{});
          }
        }

        setStatus('Organisation créée ✅');
        alert('Organisation créée. Les membres reçoivent un e-mail (à accepter).');
        orgMembersInp.value = '';
        updateInviteBtnState();
        await scanOrganizations();
      }

      // Inviter des e-mails à une org existante (ou la créer si absente)
      async function inviteMembersToOrg(){
        const name = orgNameInp.value.trim();
        const emails = splitEmails(orgMembersInp.value);
        if (!name){ alert('Indique le nom de l’organisation.'); return; }
        if (!emails.length){ alert('Ajoute au moins un e-mail.'); return; }
        const createPersonals = !!orgCreatePersonals.checked;
        const sendInv = !!orgSendInvites.checked;

        setStatus('Invitation en cours…');

        // Scanner pour trouver l’org existante (propriétaire)
        const list = await gfetch('/users/me/calendarList', { query:{ maxResults:'250' }});
        const items = Array.isArray(list.items)?list.items:[];
        let general = items.find(c => c.summary === (ORG_PREFIX+name+' · General'));
        let generalId = general?.id;

        // Si pas d’org, on la crée automatiquement (Général)
        if (!generalId){
          const created = await gfetch('/calendars', { method:'POST', body:{ summary: ORG_PREFIX + name + ' · General' }});
          generalId = created.id;
          await gfetch('/users/me/calendarList', { method:'POST', body:{ id: generalId } }).catch(()=>{});
        }

        // Donne accès writer au Général (+ e-mail d’invitation si coché)
        for (const m of emails){
          await gfetch(`/calendars/${encodeURIComponent(generalId)}/acl`, {
            method:'POST', query:{ sendNotifications: sendInv?'true':'false' },
            body:{ role:'writer', scope:{ type:'user', value:m } }
          }).catch(()=>{});
        }

        // Perso optionnel : créer le calendrier “Member · email” + writer pour le membre
        if (createPersonals){
          // Re-scan rapide pour éviter doublons
          const again = await gfetch('/users/me/calendarList', { query:{ maxResults:'250' }});
          const all   = Array.isArray(again.items)?again.items:[];
          for (const m of emails){
            const want = ORG_PREFIX + name + ' · Member · ' + m;
            let cal = all.find(c => c.summary === want);
            if (!cal){
              cal = await gfetch('/calendars', { method:'POST', body:{ summary: want }});
              await gfetch('/users/me/calendarList', { method:'POST', body:{ id: cal.id } }).catch(()=>{});
            }
            await gfetch(`/calendars/${encodeURIComponent(cal.id)}/acl`, {
              method:'POST', query:{ sendNotifications: sendInv?'true':'false' },
              body:{ role:'writer', scope:{ type:'user', value:m } }
            }).catch(()=>{});
          }
        }

        alert('Invitations envoyées.');
        orgMembersInp.value = '';
        updateInviteBtnState();
        setStatus('Invitations envoyées ✅');
        await scanOrganizations();
      }

      // ======= IMPORT (mois visible) =======
      function monthRangeISO(){
        const start = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), 1, 0,0,0,0);
        const end   = new Date(currentMonth.getFullYear(), currentMonth.getMonth()+1, 0, 23,59,59,999);
        return { timeMin: start.toISOString(), timeMax: end.toISOString() };
      }
      function toYmdFromGoogle(ev){
        if (ev && ev.start && ev.start.date) return ev.start.date;
        const iso = ev && ev.start ? (ev.start.dateTime || ev.start.date) : null;
        if (!iso) return null;
        const d = new Date(iso); if (isNaN(d)) return null;
        return ymd(d);
      }
      function dedupeMerge(base, incoming){
        const byGid = new Map(), bySig = new Map();
        for (const e of base){
          if (e.gid) byGid.set(e.gid, 1);
          else bySig.set(e.cal+'|'+e.date+'|'+e.title, 1);
        }
        const out = base.slice();
        for (const e of incoming){
          if (e.gid && byGid.has(e.gid)) continue;
          const sig = e.cal+'|'+e.date+'|'+e.title;
          if (!e.gid && bySig.has(sig)) continue;
          out.push(e);
        }
        return out;
      }

      function orgCalKey(orgName, label){ return orgName+'::'+label; } // ex: “Famille Martin::General” ou “Projet::member:email”
      function colorFor(text){
        let h=0; for (let i=0;i<text.length;i++) h=(h*31 + text.charCodeAt(i))>>>0;
        const hue = h % 360; return `hsl(${hue}deg 70% 45%)`;
      }

      function activeCalendarsFromSelection(){
        // Construit la liste des "calendriers logiques" (General + member…) pour les organisations cochées
        const map = [];
        const addOrg = (o)=>{
          if (!o) return;
          // Général
          map.push({ key: orgCalKey(o.name,'General'), label: o.name+' — Général', color: '#4CAF50', gId: o.generalId });
          // Membres
          (o.members||[]).forEach(m=>{
            map.push({ key: orgCalKey(o.name,'member:'+m.email), label: o.name+' — '+m.email, color: colorFor(o.name+'|'+m.email), gId: m.calId });
          });
        };
        orgsOwned.filter(o=>selectedOrgs.has(o.name)).forEach(addOrg);
        orgsShared.filter(o=>selectedOrgs.has(o.name)).forEach(addOrg);
        return map;
      }

      async function importSelectedOrgsMonth(){
        const sel = Array.from(selectedOrgs);
        if (!sel.length){ alert('Coche au moins une organisation.'); return; }
        setStatus('Import du mois en cours…');

        const { timeMin, timeMax } = monthRangeISO();
        const incoming = [];
        const active = activeCalendarsFromSelection();

        for (const cal of active){
          if (!cal.gId) continue; // pas de calendrier Google (ex: org partagée incomplète)
      const data = await gfetch(`/calendars/${encodeURIComponent(cal.gId)}/events`, {
        query:{ maxResults:'2500', singleEvents:'true', orderBy:'startTime', timeMin, timeMax }
      });
      const items = Array.isArray(data.items)?data.items:[];
      for (const ev of items){
        if (ev.status==='cancelled') continue;
        const date = toYmdFromGoogle(ev); if (!date) continue;
        const title = (ev.summary||'(Sans titre)').trim();
        incoming.push({ id: uid(), cal: cal.key, date, title, gid: ev.id });
      }
        }

        events = dedupeMerge(events, incoming);
        saveEvents();
        buildFilters();
        renderGrid();
        renderDayPanel();
        setStatus('Import terminé.');
        alert('Affichage mis à jour pour le mois visible.');
      }

      async function importPrimaryToSelectedOrg(){
        const sel = Array.from(selectedOrgs);
        if (sel.length!==1){ alert('Sélectionne exactement 1 organisation (case cochée).'); return; }
        const orgName = sel[0];
        const org = orgsOwned.find(o=>o.name===orgName) || orgsShared.find(o=>o.name===orgName);
        if (!org || !org.generalId){ alert('Organisation invalide ou sans calendrier Général.'); return; }

        setStatus('Import de votre calendrier principal → Général…');
        const { timeMin, timeMax } = monthRangeISO();
        const data = await gfetch('/calendars/primary/events', {
          query:{ maxResults:'2500', singleEvents:'true', orderBy:'startTime', timeMin, timeMax }
        });
        const items = Array.isArray(data.items)?data.items:[];
        const incoming = [];
        const calKey = orgCalKey(orgName,'General');

        for (const ev of items){
          if (ev.status==='cancelled') continue;
          const date = toYmdFromGoogle(ev); if (!date) continue;
          const title=(ev.summary||'(Sans titre)').trim();
          incoming.push({ id: uid(), cal: calKey, date, title, gid: 'primary:'+ev.id });
        }

        events = dedupeMerge(events, incoming);
        saveEvents(); buildFilters(); renderGrid(); renderDayPanel();
        setStatus('Import (primary → Général) terminé.');
        alert('Import terminé (mois visible).');
      }

      // ======= RENDU / UI AGENDA =======
      const MONTHS_FR   = ['janvier','février','mars','avril','mai','juin','juillet','août','septembre','octobre','novembre','décembre'];

      function renderMonthHeader(){
        const label = MONTHS_FR[currentMonth.getMonth()]+' '+currentMonth.getFullYear();
        monthLbl.textContent = label.charAt(0).toUpperCase()+label.slice(1);
      }
      function startOfWeekIndex(d){ return (d.getDay()+6)%7; } // Lundi=0

      function renderGrid(){
        renderMonthHeader();
        grid.innerHTML = '';
        const first = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), 1);
        const daysInMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth()+1, 0).getDate();
        const leading = startOfWeekIndex(first);
        for (let i=0;i<leading;i++){
          const cell=document.createElement('div'); cell.className='ag-day muted';
          // Let CSS handle the background so theme switches update appearance live.
          cell.style.cssText='min-height:96px; border-radius:12px; opacity:.5;';
          grid.appendChild(cell);
        }
        for (let day=1; day<=daysInMonth; day++){
          const d = new Date(currentMonth.getFullYear(), currentMonth.getMonth(), day);
          const id = ymd(d);
          const cell = document.createElement('div'); cell.className='ag-day'; cell.dataset.date=id;
          // Keep layout consistent; background is provided by CSS to respect theme changes.
          cell.style.cssText='min-height:120px; border-radius:14px; padding:8px; border:1px solid rgba(0,0,0,.06); display:flex; flex-direction:column; gap:6px;';
          if (id === selectedDay) cell.classList.add('is-selected');
          const head=document.createElement('div'); head.style.cssText='display:flex; align-items:center; justify-content:space-between; gap:8px;';
          head.innerHTML='<div style="font-weight:600">'+day+'</div>'+(id===todayYMD()?'<span class="badge">Aujourd’hui</span>':'');
          const listWrap=document.createElement('div'); listWrap.style.cssText='display:flex; flex-direction:column; gap:4px;';
          const dayEvents = events.filter(e => e.date === id && visible.has(e.cal));
          dayEvents.slice(0,3).forEach(ev=>{
            const pill=document.createElement('div'); pill.className='ag-pill';
            const col = colorFor(ev.cal);
            pill.title=ev.title;
            pill.innerHTML='<span style="width:10px; height:10px; border-radius:50%; background:'+col+'"></span><span style="flex:1; overflow:hidden; text-overflow:ellipsis;">'+esc(ev.title)+'</span>';
            pill.dataset.id=ev.id; listWrap.appendChild(pill);
          });
          if (dayEvents.length>3){
            const more=document.createElement('div'); more.className='muted'; more.style.cssText='font-size:12px;'; more.textContent='+'+(dayEvents.length-3)+' autres…';
            listWrap.appendChild(more);
          }
          cell.appendChild(head); cell.appendChild(listWrap); grid.appendChild(cell);
        }
      }

      function buildFilters(){
        // Construit les chips à partir des org cochées
        if (!filtersWrap) return;
        const active = activeCalendarsFromSelection();
        if (!active.length){ filtersWrap.innerHTML = '<div class="muted">Aucune organisation sélectionnée.</div>'; return; }

        // Initialiser visible si vide
        if (!visible || !(visible instanceof Set) || visible.size===0){
          visible = new Set(active.map(a=>a.key));
          saveVisible();
        }

        filtersWrap.innerHTML = '';
        active.forEach(c=>{
          const label=document.createElement('label'); label.className='ag-chip';
          const cb=document.createElement('input'); cb.type='checkbox'; cb.checked=visible.has(c.key);
          const dot=document.createElement('span'); dot.className='dot'; dot.style.background=c.color || colorFor(c.key);
          const txt=document.createElement('span'); txt.textContent=c.label;
          cb.addEventListener('change', ()=>{
            if (cb.checked) visible.add(c.key); else visible.delete(c.key);
            saveVisible(); renderGrid(); renderDayPanel();
          });
          label.appendChild(cb); label.appendChild(dot); label.appendChild(txt);
          filtersWrap.appendChild(label);
        });

        // Dropdown ajout rapide
        if (quickCal){
          quickCal.innerHTML='';
          active.forEach(c=>{ const o=document.createElement('option'); o.value=c.key; o.textContent=c.label; quickCal.appendChild(o); });
        }
      }

      function renderDayPanel(){
        if (!selectedDay){ dayTitle.textContent='Sélectionne un jour…'; dayList.innerHTML=''; dayEmpty.style.display='block'; quickForm.style.display='none'; return; }
        const d = parseYMD(selectedDay);
        dayTitle.textContent = d ? d.toLocaleDateString('fr-FR',{weekday:'long',day:'2-digit',month:'long',year:'numeric'}) : selectedDay;
        const items = events.filter(e=> e.date===selectedDay && visible.has(e.cal)).sort((a,b)=>a.cal.localeCompare(b.cal));
        dayList.innerHTML='';
        if (items.length===0){
          dayEmpty.style.display='block';
        } else {
          dayEmpty.style.display='none';
          const frag=document.createDocumentFragment();
          for (const ev of items){
            const row=document.createElement('div'); row.className='card';
            row.style.cssText='display:flex; align-items:center; justify-content:space-between; gap:10px; padding:8px 10px;';
            row.innerHTML='<div style="display:flex; align-items:center; gap:8px; min-width:0;">'
            +'<span style="width:10px; height:10px; border-radius:50%; background:'+colorFor(ev.cal)+'"></span>'
            +'<div style="font-weight:600;">'+esc(ev.cal.split('::')[0])+'</div>'
            +'<div style="opacity:.8; overflow:hidden; text-overflow:ellipsis;">— '+esc(ev.title)+'</div></div>'
            +'<div><button class="btn" data-act="edit" data-id="'+ev.id+'">✏️</button>'
            +'<button class="btn danger" data-act="del" data-id="'+ev.id+'">🗑️</button></div>';
            frag.appendChild(row);
          }
          dayList.appendChild(frag);
        }
        quickForm.style.display='flex';
      }

      // ======= DONNÉES LOCALES (ajout/édition) =======
      function addEvent(calKey, dateYmd, title, gid){
        const obj = { id: uid(), cal: calKey, date: dateYmd, title: String(title||'').trim() };
        if (gid) obj.gid = gid;
        events.push(obj);
        saveEvents();
        renderGrid();
        renderDayPanel();
      }

      function deleteEvent(id){
        const i = events.findIndex(e => e.id === id);
        if (i !== -1){
          events.splice(i, 1);
          saveEvents();
          renderGrid();
          renderDayPanel();
        }
      }

      function editEvent(id, title){
        const e = events.find(x => x.id === id);
        if (!e) return;
        e.title = String(title || '').trim();
        saveEvents();
        renderGrid();
        renderDayPanel();
      }

      // ======= NAVIGATION / HANDLERS =======
      function goMonth(delta){ currentMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth()+delta, 1); renderGrid(); renderDayPanel(); }

      function init(cont){
        try {
          // ==== Récup des éléments ====
          container  = cont;
          grid       = container.querySelector('#ag-grid');
          monthLbl   = container.querySelector('#ag-month');
        btnPrev    = container.querySelector('#ag-prev');
        btnNext    = container.querySelector('#ag-next');
        btnToday   = container.querySelector('#ag-today');
        whoSel     = container.querySelector('#ag-who'); // pas utilisé ici mais conservé si présent
        filtersWrap= container.querySelector('#ag-cal-filters');
        quickForm  = container.querySelector('#ag-quick-form');
        quickCal   = container.querySelector('#ag-quick-cal');
        quickTitle = container.querySelector('#ag-quick-title');
        quickAdd   = container.querySelector('#ag-quick-add');
        dayTitle   = container.querySelector('#ag-day-title');
        dayList    = container.querySelector('#ag-day-list');
        dayEmpty   = container.querySelector('#ag-day-empty');

        // Google / Orgs UI
        statusEl   = container.querySelector('#gcal-status');
        btnConnect = container.querySelector('#gcal-connect');
        btnLogout  = container.querySelector('#gcal-logout');
        orgNameInp = container.querySelector('#org-name');
        orgMembersInp = container.querySelector('#org-members');
        orgCreatePersonals = container.querySelector('#org-create-personals');
        orgSendInvites     = container.querySelector('#org-send-invites');
        orgCreateBtn = container.querySelector('#org-create-btn');
        orgRefreshBtn= container.querySelector('#org-refresh');
        orgOwnedList = container.querySelector('#org-owned-list');
        orgSharedList= container.querySelector('#org-shared-list');
        orgImportBtn = container.querySelector('#org-import');
        orgImportPrimaryBtn = container.querySelector('#org-import-primary');
        const orgInviteBtn = container.querySelector('#org-invite');

  // ==== État local & rendu initial ====
  try { console.log('[AGENDA] init start', { container: !!container && container.id ? container.id : (container?container.tagName:container), grid: !!grid, monthLbl: !!monthLbl, btnPrev: !!btnPrev, btnNext: !!btnNext, btnToday: !!btnToday }); } catch(e){}
  loadAll();
  // ensure selectedDay is initialized before first render
  selectedDay = todayYMD();
  // build filters (initialise `visible`) before rendering the grid
  try{ if (typeof buildFilters === 'function') buildFilters(); }catch{}
  renderGrid();
  renderDayPanel();
          try { console.log('[AGENDA] post-render', { monthLabel: monthLbl && monthLbl.textContent, eventsCount: Array.isArray(events)?events.length:0, visibleCount: (visible && visible.size)||0, selectedDay }); } catch(e){}

        // ==== Correctif "refresh normal" ====
        const hadSaved = !!loadSavedToken(); // existe un jeton valide ?
        if (hadSaved) {
          whoAmI().then(me=>{
            if (me && me.email) setStatus('Connecté : ' + me.email);
            updateGoogleButtons();
            scanOrganizations();
          });
        } else {
          // tentative silencieuse (sans popup)
          silentReconnect().then(()=>{
            updateGoogleButtons();
            if (loadSavedToken()) scanOrganizations();
          });
        }

        // ==== Handlers ====
        if (grid) {
          grid.addEventListener('click', function (e) {
            const cell = e.target.closest('.ag-day[data-date]');
            if (cell) {
              selectedDay = cell.dataset.date;
              renderGrid();
              renderDayPanel();
              return;
            }
            const pill = e.target.closest('.ag-pill');
            if (pill) {
              const ev = events.find(x => x.id === pill.dataset.id);
              if (!ev) return;
              const next = prompt('Modifier le titre :', ev.title);
              if (next && next.trim()) editEvent(ev.id, next);
            }
          });
        }

        if (quickAdd) {
          quickAdd.addEventListener('click', function () {
            if (!selectedDay) return;
            const calKey = quickCal ? quickCal.value : null;
            const title = quickTitle ? quickTitle.value : '';
            if (!calKey || !title.trim()) return;
            addEvent(calKey, selectedDay, title);
            if (quickTitle) quickTitle.value = '';
          });
        }

        if (dayList) {
          dayList.addEventListener('click', function (e) {
            const btn = e.target.closest('button[data-act]');
            if (!btn) return;
            const id = btn.dataset.id;
            const act = btn.dataset.act;
            const ev = events.find(x => x.id === id);
            if (!ev) return;

            if (act === 'del') {
              if (confirm('Supprimer ?')) deleteEvent(id);
            } else if (act === 'edit') {
              const next = prompt('Modifier le titre :', ev.title);
              if (next && next.trim()) editEvent(id, next);
            }
          });
        }

        if (btnPrev)  btnPrev.addEventListener('click', function () { goMonth(-1); });
        if (btnNext)  btnNext.addEventListener('click', function () { goMonth(1); });
        if (btnToday) btnToday.addEventListener('click', function () {
          currentMonth = new Date(); currentMonth.setDate(1);
          selectedDay = todayYMD();
          renderGrid(); renderDayPanel();
        });

        if (btnConnect) {
          btnConnect.addEventListener('click', async function () {
            try {
              setStatus('Connexion...');
              await ensureToken(true);
              const me = await whoAmI();
              if (me && me.email) {
                setStatus('Connecté : ' + me.email);
              } else {
                setStatus('Connecté à Google.');
              }
              updateGoogleButtons();
              await scanOrganizations();
            } catch (e) {
              setStatus('Échec de connexion Google.');
              alert(e && e.message ? e.message : e);
            }
          });
        }

        if (btnLogout) {
          btnLogout.addEventListener('click', function () {
            disconnectGoogle();
            if (orgOwnedList)  orgOwnedList.innerHTML  = '';
            if (orgSharedList) orgSharedList.innerHTML = '';
          });
        }

        if (orgCreateBtn) {
          orgCreateBtn.addEventListener('click', async function () {
            try {
              await ensureToken(true);
              await createOrganization();
            } catch (e) {
              alert(e && e.message ? e.message : e);
            }
          });
        }

        if (orgRefreshBtn) {
          orgRefreshBtn.addEventListener('click', async function () {
            try {
              await ensureToken(true);
              await scanOrganizations();
            } catch (e) {
              alert(e && e.message ? e.message : e);
            }
          });
        }

        // === Inviter les membres (bouton à côté du champ) ===
        window.updateInviteBtnState = function () {
          const txt = (orgMembersInp && orgMembersInp.value || '').trim();
          const connected = !!(loadSavedToken() || accessToken);
          const orgInviteBtn = container.querySelector('#org-invite');
          if (orgInviteBtn) orgInviteBtn.disabled = (txt.length === 0) || !connected;
        };
          if (orgMembersInp) {
            orgMembersInp.addEventListener('input', window.updateInviteBtnState);
            window.updateInviteBtnState();
          }
          {
            const orgInviteBtn = container.querySelector('#org-invite');
            if (orgInviteBtn) {
              orgInviteBtn.addEventListener('click', async function () {
                try {
                  await ensureToken(true);
                  await inviteMembersToOrg();
                } catch (e) {
                  alert(e && e.message ? e.message : e);
                }
              });
            }
          }

          if (orgImportBtn) {
            orgImportBtn.addEventListener('click', async function () {
              try {
                await ensureToken(true);
                await importSelectedOrgsMonth();
              } catch (e) {
                alert(e && e.message ? e.message : e);
              }
            });
          }

          if (orgImportPrimaryBtn) {
            orgImportPrimaryBtn.addEventListener('click', async function () {
              try {
                await ensureToken(true);
                await importPrimaryToSelectedOrg();
              } catch (e) {
                alert(e && e.message ? e.message : e);
              }
            });
          }
          } catch (err) {
            // Log the error clearly so users/developers can see why the Agenda tab failed
            try { console.error('Agenda init error:', err); } catch(e){}
            // Attempt minimal graceful degradation: expose basic UI elements so user can still interact
            try { if (container) { container.querySelectorAll('button').forEach(b=>b.disabled=false); } } catch(e){}
          }
      }; // <-- FIN de function init(cont)
    return { init, destroy(){ /* no-op */ } };
})();
export default AgendaModule;
