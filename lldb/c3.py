import lldb

def String_Summary(valobj, internal_dict):
    # Get the pointer and length fields from your 'String' struct
    ptr_val = valobj.GetChildMemberWithName("ptr").GetValueAsUnsigned(0)
    len_val = valobj.GetChildMemberWithName("len").GetValueAsUnsigned(0)
    
    if len_val == 0:
        return '""'
    
    # Read exactly 'len_val' bytes from the process memory
    error = lldb.SBError()
    process = valobj.GetProcess()
    data = process.ReadMemory(ptr_val, len_val, error)
    
    if error.Success():
        # Decode as UTF-8 or keep as raw bytes
        return f'"{data.decode("utf-8", "replace")}"'
    else:
        return f'<error reading memory: {error.GetCString()}>'

