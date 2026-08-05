// Sets the herdr tab label from the session title (LLM-generated or user-text fallback).
// Updates whenever a real title arrives. Resets when a new session starts in the same tab.
// Companion to herdr-agent-state.js — does not touch state/session reporting.

import net from "node:net";

// Mirrors Session.isDefaultTitle() in OpenCode — these are placeholder titles,
// not meaningful context.
function isPlaceholderTitle(title) {
  return /^(New session - |Child session - )\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(title);
}

function deriveTitle(text) {
  const cleaned = text
    .replace(/^```[^\n]*\n[\s\S]*?```\s*/gm, "") // fenced code blocks
    .replace(/@\S+/g, "")                          // @file references
    .replace(/\s+/g, " ")
    .trim();

  if (!cleaned) return null;

  return cleaned.length <= 40 ? cleaned : cleaned.slice(0, 38) + "…";
}

function rpc(socketPath, method, params) {
  const req = { id: `opencode-title:${Date.now()}`, method, params };
  return new Promise((resolve) => {
    const client = net.createConnection(socketPath, () => {
      client.write(`${JSON.stringify(req)}\n`);
    });
    const finish = () => { client.destroy(); resolve(null); };
    client.setTimeout(500, finish);
    client.on("data", (data) => {
      try { resolve(JSON.parse(data.toString())); } catch (_) { resolve(null); }
      client.destroy();
    });
    client.on("error", finish);
    client.on("end", finish);
    client.on("close", () => resolve(null));
  });
}

export const HerdrAutoTitlePlugin = async () => {
  const socketPath = process.env.HERDR_SOCKET_PATH;
  const paneId = process.env.HERDR_PANE_ID;

  if (process.env.HERDR_ENV !== "1" || !socketPath || !paneId) {
    return {};
  }

  // Resolve the tab that contains our pane.
  const paneInfo = await rpc(socketPath, "pane.get", { pane_id: paneId });
  const tabId = paneInfo?.result?.pane?.tab_id;
  if (!tabId) return {};

  // Track the session currently "owning" the tab label.
  // When sessionID changes, we rename the tab again (reset for new session).
  let currentSessionID = null;

  async function setTabTitle(sessionID, title) {
    currentSessionID = sessionID;
    await rpc(socketPath, "tab.rename", { tab_id: tabId, label: title });
  }

  return {
    // Fires on every new user prompt with parts already populated.
    // Sets a user-text title immediately for new sessions, before the LLM title arrives.
    "chat.message": async ({ sessionID }, { parts }) => {
      // Same session — LLM title will arrive via session.updated, don't overwrite.
      if (!sessionID || sessionID === currentSessionID) return;

      const text = parts
        .filter((p) => p.type === "text" && !p.synthetic)
        .map((p) => p.text)
        .join(" ");

      const title = deriveTitle(text);
      if (!title) return;

      await setTabTitle(sessionID, title);
    },

    // Fires on session resume (session.created) and whenever OpenCode updates the
    // session title (session.updated) — including when the LLM-generated title arrives.
    // Always update on a real title so the LLM title wins over our user-text placeholder.
    event: async ({ event }) => {
      const type = event?.type;
      if (type !== "session.created" && type !== "session.updated") return;

      const info = event.properties?.info;
      if (!info?.id || !info.title) return;
      if (info.parentID) return; // ignore subagent sessions
      if (isPlaceholderTitle(info.title)) return; // skip "New session - <timestamp>"

      const title = deriveTitle(info.title);
      if (!title) return;

      await setTabTitle(info.id, title);
    },
  };
};
