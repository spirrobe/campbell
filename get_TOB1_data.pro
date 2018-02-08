; 	get_TOB1_data
;	reads TOB1 files, as long as the record structure is not too complicated
;	currrently it is expected, that the first three columns are ulonarr and contain time and record number information
;	the rest should be IEEE4 !!!!
;


function get_TOB1_data,filename,jtime=jtime,mNaN=mNaN

  

  get_TOB1_ascii_header, filename, TOB1_head,ahead_len

  openr, uu, filename, /GET_LUN
  fisiz=fstat(uu)

; catch special case from Namibia, but only if there is an even number of FP2
  ix=where(TOB1_head.FieldDataTypes eq 'FP2',cnt)

  if cnt eq 2 then n_col=n_elements(TOB1_head.FieldUnits)-1 else n_col=n_elements(TOB1_head.FieldUnits)
  n_row=(fisiz.size-ahead_len)/(n_col*4)

; read the ulongs, works only, if FP2 is even
  dat=ulonarr(n_col,n_row)
  point_lun,uu,ahead_len
  readu, uu, dat
  jtime=reform(double(dat[0,*])/(24d*3600d)+double(dat[1,*])/(double(1000000000)*3600*24)+julday(12,31,1989))+0.5

; read the FP2
  if cnt eq 2 then begin
    dat=intarr(n_col*2,n_row)
    point_lun,uu,ahead_len
    readu, uu, dat
    lasttwo=dat[n_col*2-2:*,*]
  endif

  dat=fltarr(n_col,n_row)
  point_lun,uu,ahead_len
  readu, uu, dat

  if cnt eq 2 then begin
    dat=dat[0:n_col-2,*]
    dat=[dat,float(lasttwo)]
  endif


  if not keyword_set(mNaN) then begin
    ix=where(finite(dat) eq 0)
    if ix[0] ne -1 then dat[ix]=-999999.
  endif

  free_lun, uu


  return,dat[3:*,*]

end

;+
;NAME:             get_TOB1_ascii_header
;
;PURPOSE:          gets the information of ascii header of a TOB1-file
;
;OUTPUT:           TOB1_head           structure with header information
;                  ahead_len           header length
;
;REVISION HISTORY: june 2004 RV, weiter abgewandelt via CAPAC
;-

PRO get_TOB1_ascii_header, file, TOB1_head,ahead_len

  asc_head  = STRARR(5)   ;ascii header consists of five lines
  zeile     = ' '
  ahead_len = 0           ;variable for length of ascii header

  ;read ascii header
  OPENR, 3,file
  FOR i=0,4 DO BEGIN
      READF, 3,zeile
    asc_head[i] = zeile
   ; print,STRLEN(asc_head[i])
    ahead_len   = ahead_len+STRLEN(asc_head[i])+2 ;add single line lengths plus CRLF
  ENDFOR
  FREE_LUN, 3

;  PRINT, 'header: '+STRCOMPRESS(STRING(ahead_len),/REMOVE_ALL)+' bytes'

  ;splitting each row of ascii header
  z1 = STRSPLIT(asc_head[0],',',/EXTRACT)
  z2 = STRSPLIT(asc_head[1],',',/EXTRACT)
  z3 = STRSPLIT(asc_head[2],',',/EXTRACT)
  z4 = STRSPLIT(asc_head[3],',',/EXTRACT)
  z5 = STRSPLIT(asc_head[4],',',/EXTRACT)

  TOB1_head={$;row 1
             FileType                      : '', $
             StationName                   : '', $
             ModelName                     : '', $
             SerialNumber                  : '', $
             OS_Version                    : '', $
             DLD_Name                      : '', $
             ValidationStamp               : '', $
             TableName                     : '', $
             FieldNames                    : STRARR(N_ELEMENTS(z2)), $ ; row 2
             FieldUnits                    : STRARR(N_ELEMENTS(z3)), $ ; row 3
             FieldProcessing               : STRARR(N_ELEMENTS(z4)), $ ; row 4
             FieldDataTypes                : STRARR(N_ELEMENTS(z5))}   ; row 5

  ;row 1
  FOR i=0,7 DO TOB1_head.(i) = STRMID(z1[i],1,STRLEN(z1[i])-2)
  ;row 2-5
  FOR i=0,N_ELEMENTS(z2)-1 DO TOB1_head.FieldNames[i]      = STRMID(z2[i],1,STRLEN(z2[i])-2)
  FOR i=0,N_ELEMENTS(z3)-1 DO TOB1_head.FieldUnits[i]      = STRMID(z3[i],1,STRLEN(z3[i])-2)
  FOR i=0,N_ELEMENTS(z4)-1 DO TOB1_head.FieldProcessing[i] = STRMID(z4[i],1,STRLEN(z4[i])-2)
  FOR i=0,N_ELEMENTS(z5)-1 DO TOB1_head.FieldDataTypes[i]  = STRMID(z5[i],1,STRLEN(z5[i])-2)

END
