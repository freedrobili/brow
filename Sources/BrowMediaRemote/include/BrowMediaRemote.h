#ifndef BROW_MEDIA_REMOTE_H
#define BROW_MEDIA_REMOTE_H

/// Prints a JSON line with the now playing info at start and on every change.
/// Never returns; exits with status 0 when stdin reaches EOF (the parent app went away).
void brow_stream(void);

/// Executes BROW_MR_COMMAND (play|pause|toggle|next|previous|seek) with optional BROW_MR_ARG.
void brow_send(void);

#endif
