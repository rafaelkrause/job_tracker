// ── State ──────────────────────────────────────────────────────────────

const VALID_PERIODS = ["day", "week", "month"];

let currentDate = new Date();
let currentPeriod = (() => {
    const stored = localStorage.getItem("tt-period");
    return VALID_PERIODS.includes(stored) ? stored : "day";
})();
let timerInterval = null;

// ── Cross-tab sync via BroadcastChannel ───────────────────────────────

const syncChannel = new BroadcastChannel("timetrack-sync");

syncChannel.addEventListener("message", (event) => {
    if (event.data === "refresh") {
        refreshCurrentActivity();
        refreshDashboard();
    }
    if (event.data === "focus-request") {
        window.focus();
        syncChannel.postMessage("focus-ack");
    }
});

function notifyOtherTabs() {
    syncChannel.postMessage("refresh");
}

// ── Server revision polling (catches tray / external changes) ─────────

let knownRevision = -1;

async function pollRevision() {
    try {
        const data = await api("/api/revision");
        if (knownRevision === -1) {
            knownRevision = data.rev;
            return;
        }
        if (data.rev !== knownRevision) {
            knownRevision = data.rev;
            refreshCurrentActivity();
            refreshDashboard();
        }
    } catch { /* ignore network errors */ }
}

// ── Utility ───────────────────────────────────────────────────────────

function formatDateISO(d) {
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, "0");
    const day = String(d.getDate()).padStart(2, "0");
    return `${y}-${m}-${day}`;
}

// Mirrors _period_range() in routes.py — week is ISO Mon–Sun.
function periodRange(d, period) {
    if (period === "week") {
        const dow = (d.getDay() + 6) % 7; // 0 = Monday
        const start = new Date(d.getFullYear(), d.getMonth(), d.getDate() - dow);
        const end = new Date(start.getFullYear(), start.getMonth(), start.getDate() + 6);
        return [formatDateISO(start), formatDateISO(end)];
    }
    if (period === "month") {
        const start = new Date(d.getFullYear(), d.getMonth(), 1);
        const end = new Date(d.getFullYear(), d.getMonth() + 1, 0);
        return [formatDateISO(start), formatDateISO(end)];
    }
    const iso = formatDateISO(d);
    return [iso, iso];
}

function formatTime(isoStr) {
    if (!isoStr) return "—";
    const d = new Date(isoStr);
    return d.toLocaleTimeString(window.currentLang || "pt-BR", { hour: "2-digit", minute: "2-digit" });
}

function formatDuration(seconds) {
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = Math.floor(seconds % 60);
    return `${String(h).padStart(2, "0")}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`;
}

function escapeHtml(text) {
    const div = document.createElement("div");
    div.textContent = text;
    return div.innerHTML;
}

async function api(url, method = "GET", body = null) {
    const opts = { method, headers: { "Content-Type": "application/json" } };
    if (body) opts.body = JSON.stringify(body);
    const res = await fetch(url, opts);
    return res.json();
}

// ── Theme ─────────────────────────────────────────────────────────────

function initTheme() {
    const saved = localStorage.getItem("tt-theme") || window.ttServerTheme || "auto";
    applyTheme(saved);
}

function applyTheme(theme) {
    let effective = theme;
    if (theme === "auto") {
        effective = window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
    }
    document.documentElement.setAttribute("data-bs-theme", effective);
    localStorage.setItem("tt-theme", theme);
    updateThemeIcon();
}

function updateThemeIcon() {
    const btn = document.getElementById("theme-toggle");
    if (!btn) return;
    const theme = localStorage.getItem("tt-theme") || "auto";
    const icons = { dark: "bi-moon-stars-fill", light: "bi-sun-fill", auto: "bi-circle-half" };
    btn.innerHTML = `<i class="bi ${icons[theme] || icons.auto}"></i>`;
}

window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", () => {
    if ((localStorage.getItem("tt-theme") || "auto") === "auto") applyTheme("auto");
});

document.addEventListener("click", (e) => {
    if (e.target.closest("#theme-toggle")) {
        const current = localStorage.getItem("tt-theme") || "auto";
        const cycle = { light: "dark", dark: "auto", auto: "light" };
        applyTheme(cycle[current] || "light");
    }
});

// ── Language switch ───────────────────────────────────────────────────

document.addEventListener("click", async (e) => {
    const el = e.target.closest(".lang-switch");
    if (!el) return;
    e.preventDefault();
    const lang = el.dataset.lang;
    try {
        await fetch("/api/lang", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ lang }),
        });
        window.location.reload();
    } catch { /* ignore */ }
});

// ── Current Activity ──────────────────────────────────────────────────

async function refreshCurrentActivity() {
    const data = await api("/api/activity/current");
    const container = document.getElementById("current-activity");
    if (!container) return;

    if (data.activity) {
        container.classList.remove("d-none");
        container.className = container.className.replace(/border-\w+/g, "");
        document.getElementById("current-description").textContent = data.activity.description;

        const badge = document.getElementById("status-badge");
        const btnPause = document.getElementById("btn-pause");
        const btnResume = document.getElementById("btn-resume");

        if (data.activity.status === "paused") {
            badge.textContent = window.i18n.paused;
            badge.className = "badge bg-warning text-dark";
            btnPause.classList.add("d-none");
            btnResume.classList.remove("d-none");
            container.classList.add("border-warning");
        } else {
            badge.textContent = window.i18n.active;
            badge.className = "badge bg-success";
            btnPause.classList.remove("d-none");
            btnResume.classList.add("d-none");
            container.classList.add("border-success");
        }

        startTimer(data.effective_seconds, data.activity.status);
    } else {
        container.classList.add("d-none");
        stopTimer();
    }
}

function startTimer(initialSeconds, status) {
    stopTimer();
    let seconds = initialSeconds;
    updateTimerDisplay(seconds);

    if (status === "active") {
        timerInterval = setInterval(() => {
            seconds++;
            updateTimerDisplay(seconds);
        }, 1000);
    }
}

function stopTimer() {
    if (timerInterval) {
        clearInterval(timerInterval);
        timerInterval = null;
    }
}

function updateTimerDisplay(seconds) {
    const el = document.getElementById("current-timer");
    if (el) el.textContent = formatDuration(seconds);
}

// ── Activity Actions ──────────────────────────────────────────────────

async function startActivity(event) {
    event.preventDefault();
    const input = document.getElementById("activity-description");
    const description = input.value.trim();
    if (!description) return;

    await api("/api/activity/start", "POST", { description });
    input.value = "";
    refreshCurrentActivity();
    refreshDashboard();
    notifyOtherTabs();
}

async function pauseActivity() {
    await api("/api/activity/pause", "POST");
    refreshCurrentActivity();
    notifyOtherTabs();
    showPhrase("pause");
}

async function resumeActivity() {
    await api("/api/activity/resume", "POST");
    refreshCurrentActivity();
    notifyOtherTabs();
}

async function stopActivity() {
    await api("/api/activity/stop", "POST");
    refreshCurrentActivity();
    refreshDashboard();
    notifyOtherTabs();
    showPhrase("stop");
}

async function showPhrase(category) {
    try {
        const data = await api(`/api/phrase/${category}`);
        if (data.phrase) showToast(data.phrase, "info", 4000);
    } catch { /* ignore */ }
}

// ── Dashboard ─────────────────────────────────────────────────────────

function changePeriod(period) {
    if (!VALID_PERIODS.includes(period)) return;
    currentPeriod = period;
    localStorage.setItem("tt-period", period);
    updatePeriodButtons();
    updateDateDisplay();
    refreshDashboard();
}

function updatePeriodButtons() {
    for (const p of VALID_PERIODS) {
        const btn = document.getElementById(`period-${p}`);
        if (btn) btn.classList.toggle("active", p === currentPeriod);
    }
}

function changeDate(delta) {
    if (currentPeriod === "week") {
        currentDate.setDate(currentDate.getDate() + 7 * delta);
    } else if (currentPeriod === "month") {
        currentDate.setDate(1);
        currentDate.setMonth(currentDate.getMonth() + delta);
    } else {
        currentDate.setDate(currentDate.getDate() + delta);
    }
    updateDateDisplay();
    refreshDashboard();
}

function goToday() {
    currentDate = new Date();
    updateDateDisplay();
    refreshDashboard();
}

function weekRange(d) {
    // Monday (ISO) through Sunday — weekday(): 0=Sun ... 1=Mon in JS
    const day = d.getDay(); // 0=Sun ... 6=Sat
    const diffToMonday = (day + 6) % 7;
    const start = new Date(d);
    start.setDate(d.getDate() - diffToMonday);
    const end = new Date(start);
    end.setDate(start.getDate() + 6);
    return { start, end };
}

function updateDateDisplay() {
    const el = document.getElementById("date-display");
    if (!el) return;
    const lang = window.currentLang || "pt-BR";

    if (currentPeriod === "week") {
        const { start, end } = weekRange(currentDate);
        const startStr = start.toLocaleDateString(lang, { day: "2-digit", month: "short" });
        const endStr = end.toLocaleDateString(lang, { day: "2-digit", month: "short" });
        el.textContent = `${startStr} \u2013 ${endStr}`;
        return;
    }

    if (currentPeriod === "month") {
        el.textContent = currentDate.toLocaleDateString(lang, { month: "long", year: "numeric" });
        return;
    }

    const todayStr = formatDateISO(new Date());
    const currentStr = formatDateISO(currentDate);
    if (currentStr === todayStr) {
        el.textContent = window.i18n.today;
    } else {
        el.textContent = currentDate.toLocaleDateString(lang, {
            weekday: "short", day: "2-digit", month: "2-digit",
        });
    }
}

async function refreshDashboard() {
    const dateStr = formatDateISO(currentDate);
    const data = await api(`/api/dashboard?date=${dateStr}&period=${currentPeriod}`);

    // Stats
    const trackedEl = document.getElementById("tracked-time");
    const shiftEl = document.getElementById("shift-total");
    const pctEl = document.getElementById("percentage");
    const bar = document.getElementById("progress-bar");

    if (trackedEl) trackedEl.textContent = formatDuration(data.tracked_seconds);
    if (shiftEl) {
        // Day: show elapsed-so-far (matches the "%-of-elapsed" percentage).
        // Week/Month: show total shift hours for the period (what the user asked for).
        shiftEl.textContent = formatDuration(
            currentPeriod === "day" ? data.elapsed_shift_seconds : data.total_shift_seconds
        );
    }

    if (pctEl) {
        pctEl.textContent = `${data.percentage}%`;
        const t = data.target_percentage;
        pctEl.className = "fw-bold " + (
            data.percentage >= t ? "pct-high" :
            data.percentage >= t * 0.7 ? "pct-mid" : "pct-low"
        );
    }

    if (bar) {
        const pct = Math.min(100, data.percentage);
        bar.style.width = `${pct}%`;
        const t = data.target_percentage;
        bar.className = "progress-bar " + (
            data.percentage >= t ? "bg-success" :
            data.percentage >= t * 0.7 ? "bg-warning" : "bg-danger"
        );
    }

    // Timeline card is day-only
    const timelineCard = document.getElementById("timeline-card");
    if (timelineCard) {
        timelineCard.style.display = currentPeriod === "day" ? "" : "none";
    }

    // Shift info (day mode only — shown in timeline card header)
    const shiftInfo = document.getElementById("shift-info");
    if (shiftInfo) {
        shiftInfo.textContent = data.shifts.length > 0
            ? data.shifts.map(s => `${s.start}\u2013${s.end}`).join(" | ")
            : window.i18n.no_shift;
    }

    if (currentPeriod === "day") {
        renderTimeline(data);
    }
    renderActivityTable(data.activities);
}

// ── Timeline ──────────────────────────────────────────────────────────

function renderTimeline(data) {
    const container = document.getElementById("timeline");
    const labelsEl = document.getElementById("timeline-labels");
    if (!container) return;
    container.innerHTML = "";
    if (labelsEl) labelsEl.innerHTML = "";

    if (data.shifts.length === 0) {
        container.innerHTML = `<div class="text-body-secondary text-center small py-3">${escapeHtml(window.i18n.no_shift)}</div>`;
        container.style.height = "auto";
        return;
    }
    container.style.height = "52px";

    // Compute timeline range
    let earliest = 24, latest = 0;
    for (const s of data.shifts) {
        const [sh, sm] = s.start.split(":").map(Number);
        const [eh, em] = s.end.split(":").map(Number);
        earliest = Math.min(earliest, sh + sm / 60);
        latest = Math.max(latest, eh + em / 60);
    }
    earliest = Math.max(0, earliest - 0.5);
    latest = Math.min(24, latest + 0.5);
    const range = latest - earliest;

    function hoursToPercent(h) {
        return ((h - earliest) / range) * 100;
    }

    function timeStrToPercent(t) {
        const [h, m] = t.split(":").map(Number);
        return hoursToPercent(h + m / 60);
    }

    function isoToPercent(iso) {
        const d = new Date(iso);
        const h = d.getHours() + d.getMinutes() / 60 + d.getSeconds() / 3600;
        return Math.max(0, Math.min(100, hoursToPercent(h)));
    }

    // Shift blocks
    for (const s of data.shifts) {
        const left = timeStrToPercent(s.start);
        const right = timeStrToPercent(s.end);
        const div = document.createElement("div");
        div.className = "timeline-shift";
        div.style.left = `${left}%`;
        div.style.width = `${right - left}%`;
        container.appendChild(div);
    }

    // Activity blocks
    for (const a of data.activities) {
        const left = isoToPercent(a.started_at);
        const endIso = a.ended_at || new Date().toISOString();
        const right = isoToPercent(endIso);
        const div = document.createElement("div");
        div.className = `timeline-activity ${a.status}`;
        div.style.left = `${left}%`;
        div.style.width = `${Math.max(0.3, right - left)}%`;
        div.title = `${a.description}\n${formatTime(a.started_at)} \u2013 ${a.ended_at ? formatTime(a.ended_at) : window.i18n.now}\n${a.effective_duration}`;
        container.appendChild(div);
    }

    // Now marker
    const todayStr = formatDateISO(new Date());
    if (formatDateISO(currentDate) === todayStr) {
        const now = new Date();
        const nowH = now.getHours() + now.getMinutes() / 60;
        if (nowH >= earliest && nowH <= latest) {
            const marker = document.createElement("div");
            marker.className = "timeline-now";
            marker.style.left = `${hoursToPercent(nowH)}%`;
            container.appendChild(marker);
        }
    }

    // Hour labels
    if (labelsEl) {
        for (let h = Math.ceil(earliest); h <= Math.floor(latest); h++) {
            const span = document.createElement("span");
            span.className = "timeline-label";
            span.style.left = `${hoursToPercent(h)}%`;
            span.textContent = `${String(h).padStart(2, "0")}h`;
            labelsEl.appendChild(span);
        }
    }
}

// ── Activity Table ────────────────────────────────────────────────────

function renderActivityTable(activities) {
    const tbody = document.getElementById("activity-table");
    if (!tbody) return;

    const showDateCol = currentPeriod !== "day";
    const colDateHeader = document.getElementById("col-date");
    if (colDateHeader) colDateHeader.style.display = showDateCol ? "" : "none";
    const colspan = showDateCol ? 7 : 6;

    if (activities.length === 0) {
        tbody.innerHTML = `<tr><td colspan="${colspan}" class="text-center text-body-secondary py-3">${escapeHtml(window.i18n.no_activities)}</td></tr>`;
        return;
    }

    const statusMap = {
        completed: { label: window.i18n.completed, cls: "bg-secondary" },
        paused:    { label: window.i18n.paused,    cls: "bg-warning text-dark" },
        active:    { label: window.i18n.active,    cls: "bg-success" },
    };

    const lang = window.currentLang || "pt-BR";

    tbody.innerHTML = activities.map(a => {
        const st = statusMap[a.status] || statusMap.completed;
        const dateCell = showDateCol
            ? `<td class="text-body-secondary small">${new Date(a.started_at).toLocaleDateString(lang, { day: "2-digit", month: "2-digit" })}</td>`
            : "";
        return `<tr>
            ${dateCell}
            <td class="cell-description">${escapeHtml(a.description)}</td>
            <td>${formatTime(a.started_at)}</td>
            <td>${a.ended_at ? formatTime(a.ended_at) : "\u2014"}</td>
            <td class="font-monospace">${a.effective_duration}</td>
            <td><span class="badge ${st.cls}">${st.label}</span></td>
            <td>
                <button class="btn btn-link btn-sm p-0 text-body-secondary btn-edit"
                    data-id="${a.id}" data-status="${a.status}"
                    data-started="${a.started_at}" data-ended="${a.ended_at || ""}"
                    title="${escapeHtml(window.i18n.edit || 'Edit')}">
                    <i class="bi bi-pencil"></i>
                </button>
            </td>
        </tr>`;
    }).join("");

    // Attach edit handlers via data attributes (safe for any description content)
    for (const btn of tbody.querySelectorAll(".btn-edit")) {
        const id = btn.dataset.id;
        const row = btn.closest("tr");
        const description = row.querySelector(".cell-description").textContent;
        btn.addEventListener("click", () => {
            openEditModal(id, description, btn.dataset.started, btn.dataset.ended, btn.dataset.status);
        });
    }
}

// ── Edit / Delete Activity ────────────────────────────────────────────

let editModalInstance = null;
let confirmSaveInstance = null;
let confirmDeleteInstance = null;

function getEditModals() {
    if (!editModalInstance) editModalInstance = new bootstrap.Modal(document.getElementById("editModal"));
    if (!confirmSaveInstance) confirmSaveInstance = new bootstrap.Modal(document.getElementById("confirmSaveModal"));
    if (!confirmDeleteInstance) confirmDeleteInstance = new bootstrap.Modal(document.getElementById("confirmDeleteModal"));
}

function openEditModal(id, description, startedAt, endedAt, status) {
    getEditModals();
    document.getElementById("edit-id").value = id;
    document.getElementById("edit-status").value = status;
    document.getElementById("edit-description").value = description;

    const startDate = new Date(startedAt);
    document.getElementById("edit-start").value =
        String(startDate.getHours()).padStart(2, "0") + ":" + String(startDate.getMinutes()).padStart(2, "0");

    const endGroup = document.getElementById("edit-end-group");
    const endInput = document.getElementById("edit-end");
    if (endedAt) {
        endGroup.classList.remove("d-none");
        const endDate = new Date(endedAt);
        endInput.value =
            String(endDate.getHours()).padStart(2, "0") + ":" + String(endDate.getMinutes()).padStart(2, "0");
    } else {
        endGroup.classList.add("d-none");
        endInput.value = "";
    }

    editModalInstance.show();
}

function showSaveConfirm() {
    editModalInstance.hide();
    confirmSaveInstance.show();
}

function showDeleteConfirm() {
    editModalInstance.hide();
    confirmDeleteInstance.show();
}

function backToEdit() {
    confirmSaveInstance.hide();
    confirmDeleteInstance.hide();
    editModalInstance.show();
}

async function saveEdit() {
    const id = document.getElementById("edit-id").value;
    const body = {
        description: document.getElementById("edit-description").value.trim(),
        start_time: document.getElementById("edit-start").value,
    };
    const endVal = document.getElementById("edit-end").value;
    if (endVal) body.end_time = endVal;

    await api(`/api/activity/${id}`, "PUT", body);
    confirmSaveInstance.hide();
    refreshCurrentActivity();
    refreshDashboard();
    notifyOtherTabs();
    showToast(window.i18n.activity_updated);
}

async function deleteActivity() {
    const id = document.getElementById("edit-id").value;
    await api(`/api/activity/${id}`, "DELETE");
    confirmDeleteInstance.hide();
    refreshCurrentActivity();
    refreshDashboard();
    notifyOtherTabs();
    showToast(window.i18n.activity_removed);
}

// ── Export ─────────────────────────────────────────────────────────────

function exportData(format) {
    const [from, to] = periodRange(currentDate, currentPeriod);
    window.open(`/api/export?from=${from}&to=${to}&format=${format}`);
}

function openExportModal() {
    const [from, to] = periodRange(currentDate, currentPeriod);
    const fromInput = document.getElementById("export-from");
    const toInput = document.getElementById("export-to");
    if (fromInput) fromInput.value = from;
    if (toInput) toInput.value = to;
    const modal = bootstrap.Modal.getOrCreateInstance(document.getElementById("exportModal"));
    modal.show();
}

function exportCustomRange() {
    const from = document.getElementById("export-from")?.value;
    const to = document.getElementById("export-to")?.value;
    const format = document.getElementById("export-format")?.value || "csv";
    if (!from || !to) {
        showToast(window.i18n.pick_dates, "warning");
        return;
    }
    window.open(`/api/export?from=${from}&to=${to}&format=${format}`);
    bootstrap.Modal.getInstance(document.getElementById("exportModal"))?.hide();
}

// ── Settings ──────────────────────────────────────────────────────────

function dayNames() {
    return {
        monday: window.i18n.monday,
        tuesday: window.i18n.tuesday,
        wednesday: window.i18n.wednesday,
        thursday: window.i18n.thursday,
        friday: window.i18n.friday,
        saturday: window.i18n.saturday,
        sunday: window.i18n.sunday,
    };
}
const DAY_ORDER = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"];

async function loadShifts() {
    const data = await api("/api/shifts");
    const container = document.getElementById("shifts-config");
    if (!container) return;

    container.innerHTML = "";
    const names = dayNames();
    for (const day of DAY_ORDER) {
        const shifts = data[day] || [];
        const dayDiv = document.createElement("div");
        dayDiv.className = "mb-3";
        dayDiv.innerHTML = `
            <div class="d-flex align-items-center gap-2 mb-1">
                <strong style="width:75px;font-size:0.85rem">${escapeHtml(names[day])}</strong>
                <button class="btn btn-outline-primary btn-sm py-0 px-1" style="font-size:0.75rem" onclick="addShift('${day}')">
                    <i class="bi bi-plus"></i>
                </button>
            </div>
            <div id="shifts-${day}" class="d-flex flex-wrap gap-2">
                ${shifts.map((s, i) => shiftInputHtml(day, i, s.start, s.end)).join("")}
            </div>
        `;
        container.appendChild(dayDiv);
    }
}

function shiftInputHtml(day, index, start, end) {
    return `<div class="input-group input-group-sm" style="width:auto">
        <input type="time" class="form-control form-control-sm" value="${start}" data-day="${day}" data-index="${index}" data-field="start">
        <span class="input-group-text py-0">\u2013</span>
        <input type="time" class="form-control form-control-sm" value="${end}" data-day="${day}" data-index="${index}" data-field="end">
        <button class="btn btn-outline-danger btn-sm py-0" onclick="this.parentElement.remove()"><i class="bi bi-x"></i></button>
    </div>`;
}

function addShift(day) {
    const container = document.getElementById(`shifts-${day}`);
    const idx = container.children.length;
    container.insertAdjacentHTML("beforeend", shiftInputHtml(day, idx, "09:00", "18:00"));
}

async function saveShifts() {
    const shifts = {};
    for (const day of DAY_ORDER) {
        shifts[day] = [];
        const container = document.getElementById(`shifts-${day}`);
        if (!container) continue;
        for (const group of container.querySelectorAll(".input-group")) {
            const inputs = group.querySelectorAll('input[type="time"]');
            if (inputs.length === 2 && inputs[0].value && inputs[1].value) {
                shifts[day].push({ start: inputs[0].value, end: inputs[1].value });
            }
        }
    }
    await api("/api/shifts", "PUT", shifts);
    showToast(window.i18n.shifts_saved);
}

async function saveGeneral() {
    const userName = document.getElementById("user-name")?.value.trim() || "";
    const target = parseInt(document.getElementById("target-percentage")?.value || "90");
    const port = parseInt(document.getElementById("server-port")?.value || "5000");
    const phrasesEnabled = document.getElementById("phrases-enabled")?.checked ?? true;
    await api("/api/config", "PUT", {
        user_name: userName,
        target_percentage: target,
        port,
        phrases_enabled: phrasesEnabled,
    });
    showToast(window.i18n.settings_saved);
}

// ── Toast ─────────────────────────────────────────────────────────────

function showToast(message, type = "success", duration = 2500) {
    let toastContainer = document.getElementById("toast-container");
    if (!toastContainer) {
        toastContainer = document.createElement("div");
        toastContainer.id = "toast-container";
        toastContainer.className = "position-fixed bottom-0 end-0 p-3";
        toastContainer.style.zIndex = "1090";
        document.body.appendChild(toastContainer);
    }
    const id = "toast-" + Date.now();
    toastContainer.insertAdjacentHTML("beforeend", `
        <div id="${id}" class="toast align-items-center text-bg-${type} border-0" role="alert">
            <div class="d-flex">
                <div class="toast-body">${escapeHtml(message)}</div>
                <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
            </div>
        </div>
    `);
    const el = document.getElementById(id);
    const toast = new bootstrap.Toast(el, { delay: duration });
    toast.show();
    el.addEventListener("hidden.bs.toast", () => el.remove());
}

// ── Init ──────────────────────────────────────────────────────────────

document.addEventListener("DOMContentLoaded", () => {
    initTheme();

    // Dashboard page
    if (document.getElementById("current-activity")) {
        updatePeriodButtons();
        updateDateDisplay();
        refreshCurrentActivity();
        refreshDashboard();

        // Lightweight revision poll every 3s — detects tray & external changes
        setInterval(pollRevision, 3000);

        // Full refresh every 30s (updates timer accuracy & dashboard stats)
        setInterval(() => {
            refreshCurrentActivity();
            refreshDashboard();
        }, 30000);
    }

});
