#pragma once

/* Function prototypes */
BOOL MIDIProbe(BYTE address, DWORD flags);
BYTE MIDIPoll(void* buf);
BOOL MIDIEventHandler(BYTE addr, BYTE event, void *data, DWORD size);

