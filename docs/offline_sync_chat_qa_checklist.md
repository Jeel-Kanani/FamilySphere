# Offline, Sync, and Chat QA Checklist

Use this checklist on a real device when validating the latest offline and sync work.

## Setup

- Login successfully while online
- Open Home, Family, Vault, Document List, at least one Document Viewer, and Family Chat once while online
- Save at least one image document for offline access
- Ensure at least one family activity item exists

## A. Cold Start Offline

- [ ] Kill the app fully
- [ ] Turn internet off
- [ ] Reopen app
- [ ] App restores session without forcing login
- [ ] Family members load from cache
- [ ] Family activity loads from cache
- [ ] Document list loads from cache quickly
- [ ] Offline image thumbnail shows actual image, not generic icon
- [ ] Offline image opens successfully
- [ ] Settings/Profile shows offline status

## B. Offline Document Actions

- [ ] Upload a document while offline
- [ ] Uploaded doc appears locally with pending sync state
- [ ] Move a document while offline
- [ ] Moved doc shows updated folder locally
- [ ] Delete a document while offline
- [ ] Deleted doc disappears locally
- [ ] Settings/Profile pending count increases correctly
- [ ] Sync history shows queued actions

## C. Offline File Management

- [ ] Open Settings/Profile
- [ ] Open `Manage Offline Files`
- [ ] Offline-saved files are listed
- [ ] File count looks correct
- [ ] Remove one offline copy
- [ ] Removed file disappears from offline files list
- [ ] That file no longer opens offline

## D. Offline Chat

- [ ] Open Family Chat while offline
- [ ] Existing messages load from local cache
- [ ] Chat header/status shows offline or queued state
- [ ] Send a new message while offline
- [ ] Message appears immediately in chat
- [ ] Message shows queued/pending visual state
- [ ] Settings/Profile still usable after offline chat queueing

## E. Reconnect and Auto Sync

- [ ] Turn internet back on
- [ ] Resume app if needed
- [ ] Status changes from offline to online/syncing
- [ ] Pending document sync count starts decreasing
- [ ] Offline chat messages send automatically
- [ ] Queued chat message visual changes from pending to sent
- [ ] Final pending count reaches zero when all sync succeeds
- [ ] Sync history shows success entries
- [ ] Last sync time updates

## F. Failed Sync and Recovery

- [ ] Force one document sync conflict if possible
- [ ] Failed count increases in Settings/Profile
- [ ] Failed sync summary is visible in Settings/Profile
- [ ] Document list shows sync failure text
- [ ] Document viewer shows failed sync banner
- [ ] Retry failed sync works when issue is temporary
- [ ] Clear failed sync removes failed state locally
- [ ] Resolve conflict action works for supported conflict cases

## G. App Resume and Background Behavior

- [ ] Queue document/chat work
- [ ] Background the app
- [ ] Reopen app after reconnect
- [ ] Auto-sync resumes without manual navigation
- [ ] No duplicate uploads/messages created

## H. Regression Checks

- [ ] Normal online document upload still works
- [ ] Normal online delete still works
- [ ] Normal online move still works
- [ ] Online chat still sends instantly
- [ ] Profile screen still saves correctly
- [ ] Sign out still works

## Notes

- Record exact device, OS version, and app build used
- If a test fails, note:
  - exact steps
  - online/offline state
  - pending count
  - failed count
  - visible error text
