use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Mutex;

use tokio::sync::mpsc::UnboundedSender;

/// Commands Dart can push into a running session loop. Milestone 1 only needs
/// Disconnect; input/clipboard-send commands are added in later milestones.
#[derive(Debug)]
pub enum SessionCmd {
    Disconnect,
}

static NEXT_ID: AtomicU32 = AtomicU32::new(1);
static SESSIONS: Mutex<Option<HashMap<u32, UnboundedSender<SessionCmd>>>> = Mutex::new(None);

pub mod registry {
    use super::*;

    pub fn insert(tx: UnboundedSender<SessionCmd>) -> u32 {
        let id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
        SESSIONS.lock().expect("session registry lock poisoned").get_or_insert_with(HashMap::new).insert(id, tx);
        id
    }

    pub fn send(id: u32, cmd: SessionCmd) -> bool {
        // Clone the sender out from under the lock so the channel send
        // (and any future drop-handler triggered by it) cannot re-enter SESSIONS.
        let tx = SESSIONS.lock().expect("session registry lock poisoned")
            .as_ref()
            .and_then(|m| m.get(&id))
            .cloned();
        match tx {
            Some(tx) => tx.send(cmd).is_ok(),
            None => false,
        }
    }

    pub fn remove(id: u32) {
        if let Some(m) = SESSIONS.lock().expect("session registry lock poisoned").as_mut() {
            m.remove(&id);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn registry_insert_send_remove() {
        let (tx, mut rx) = tokio::sync::mpsc::unbounded_channel();
        let id = registry::insert(tx);
        assert!(registry::send(id, SessionCmd::Disconnect));
        assert!(matches!(rx.try_recv().unwrap(), SessionCmd::Disconnect));
        registry::remove(id);
        assert!(!registry::send(id, SessionCmd::Disconnect));
    }
}
