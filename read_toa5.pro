
;   get_TOA5_data
; reads TOA5 files and returns a structure with header and data
;searches automatic for length of hdr (not necessary usually, but done anyway)
; IMPORTANT: Requires a timestamp structures with date behin as first entry, since it parses for this entry
function Read_TOA5,filename,add_meta=add_meta,lineskip=lineskip
  if not keyword_set(filename) then filename=dialog_pickfile(path='\\Met-server0\Messnetz\kalib\SONICS\Windkanal 2011\data')
  if not KEYWORD_SET(lineskip) then lineskip=0
  openr, lun, filename,/get_lun
  LINE_SEPERATOR=','
  hdr_lines=0L
  data_lines=0L ;counter for lines containing data
  line=''
  datafeed=''
  hdr=''
  
  linecount=0D
  
  while not eof(lun) do begin
    linecount++
    readf,lun,line
    hdrcheck=strsplit(line,line_seperator,/extract)
    ;requires date and time at pos 0 to calculate hdr-length
    hdrcheck=size(strsplit(hdrcheck[0],' ',/extract),/DIMENSIONS)
    if hdrcheck ne 2 then begin
      if hdr_lines eq 0 then hdr=line else hdr=[hdr,line]
      hdr_lines++
    endif else begin
      data_lines++
    endelse
  endwhile
  print, linecount
  hdrstring=['Metadata','FIELDNAMES','FieldUnits','FieldProcessing']
  hdrfeed=CREATE_STRUCT(hdrstring[0],STRSPLIT(hdr[0],',',/EXTRACT))
  for i=1, n_elements(hdr)-1 do begin
    intermediate=STRSPLIT(hdr[i],',',/EXTRACT)
    
    hdrfeed=create_struct(hdrfeed,hdrstring[i],STRSPLIT(hdr[i],',',/EXTRACT))
  endfor
  
  byte_hdr = total(STRLEN(hdr))+(hdr_lines)*2
  point_lun,lun,byte_hdr
  
  n_col=size(strsplit(hdr[n_elements(hdr)-1],line_seperator,/extract),/DIMENSIONS)
  
  datafeed=strarr(n_col,data_lines-lineskip)
  timeline=dblarr(data_lines-lineskip)
  count=0L
  skip_count=0L
  while not eof(lun) do begin
    readf, lun, line
    if skip_count ge lineskip then begin
      datafeed[*,count-lineskip]=(strsplit(line,line_seperator,/extract))
      timefeed=strsplit(datafeed[0,count-lineskip],'"',/extract)
      timefeed=strsplit(timefeed,' ',/extract)
      date=float(strsplit(timefeed[0],'-',/EXTRACT))
      time=float(strsplit(timefeed[1],':',/EXTRACT))
      timeline[count-lineskip]=julday(date[1],date[2],date[0],time[0],time[1],time[2])
    endif else begin
      skip_count++
    endelse
    count++
  endwhile
  free_lun, lun
  datafeed=datafeed[1:*,*]
  
  data_names=(hdrfeed.FIELDNAMES)
  for ii=0,n_elements(data_names)-1 do data_names[ii]=strsplit(DATA_NAMES[ii],'"',/extract)
  nan=where(datafeed eq '"NAN"',COMPLEMENT=non_nan)
  if nan[0] ne -1 then datafeed[nan]=-9999
  datafeed=double(datafeed)
  data=create_struct(DATA_NAMES[0],timeline[*])
  for ii=1,n_elements(data_NAMES)-1 do begin
    data=create_struct( data,DATA_NAMES[ii] ,(reform(datafeed[ii-1,*])))
  endfor
  
  if KEYWORD_SET(add_meta) then begin
    container=create_struct('Metadata',hdrfeed,'Data', data)
    return, container
  endif else begin
    return, data
  endelse
  
end
