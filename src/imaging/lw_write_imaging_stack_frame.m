function lw_write_imaging_stack_frame(frame, stackFile, pageIndex)
%LW_WRITE_IMAGING_STACK_FRAME Write or append one frame to a TIFF stack.

if pageIndex == 1
    writeMode = 'overwrite';
else
    writeMode = 'append';
end

imwrite(frame, stackFile, 'tif', 'WriteMode', writeMode, 'Compression', 'none');
end
