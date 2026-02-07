function string_summary(valobj, internal_dict)
    -- Get the fields from the C3 String struct
    local ptr_obj = valobj:GetChildMemberWithName("ptr")
    local len_obj = valobj:GetChildMemberWithName("len")
    
    if not ptr_obj:IsValid() or not len_obj:IsValid() then
        return "<invalid string>"
    end

    local length = len_obj:GetValueAsUnsigned()
    local address = ptr_obj:GetValueAsUnsigned()

    -- Read the string from memory
    local process = lldb.debugger:GetSelectedTarget():GetProcess()
    local error = lldb.SBError()
    local content = process:ReadMemory(address, length, error)
    
    if error:Success() then
        return '"' .. content .. '"'
    else
        return "<error reading memory>"
    end
end

