  
  
  
  pro get_tob3_header,file, TOB3_HDR,ahead_len
    ;Some hdr parameters, alternatively, 512 Byte can be read in and covnerted to string,
    ; yields same information. We can assume 6 Lines, as these are hardcoded. There is still a check
    ; just for certaintly/validation-
    asc_head  = STRARR(6) &  zeile= ' ' &   ahead_len = 0
    
    ;read ascii header
    OPENR, lun,file,/GET_LUN
    FOR i=0,5 DO BEGIN
      READF, lun,zeile
      asc_head[i] = zeile
      ahead_len   = ahead_len+STRLEN(asc_head[i])+2 ;add single line lengths plus CRLF
    ENDFOR
    
    POINT_LUN,-lun,pos
    
    ;checks if ahead len and pos are the same and both amount to 512 Bytes
    if pos ne ahead_len or (pos mod 512) ne 0 or (ahead_len mod 512) ne 0 then MESSAGE,'Possible Error in HDR Readin'
    
    FREE_LUN, lun &  close,lun
    z1 = STRSPLIT(asc_head[0],',',/EXTRACT) & z2 = STRSPLIT(asc_head[1],',',/EXTRACT)
    z3 = STRSPLIT(asc_head[2],',',/EXTRACT) & z4 = STRSPLIT(asc_head[3],',',/EXTRACT)
    z5 = STRSPLIT(asc_head[4],',',/EXTRACT) & z6 = STRSPLIT(asc_head[5],',',/EXTRACT)
    
    TOB3_hdr={$;row 1
      FileType                      : '', $
      StationName                   : '', $
      ModelName                     : '', $
      SerialNumber                  : '', $
      OS_Version                    : '', $
      DLD_Name                      : '', $
      DLD_Signature                 : '', $
      FileCreationTime              : '', $
      $;row 2
      TableName                     : '', $
      Non_TimestampedRecordInterval : '', $
      DataFrameSize                 : 0L, $
      IntendedTableSize             : 0L, $
      ValidationStamp               : 0L, $
      FrameTimeResolution           : '', $
      WeissNit                      : 0L, $
      $;row 3
      FieldNames                    : STRARR(N_ELEMENTS(z3)), $
      $;row 4
      FieldUnits                    : STRARR(N_ELEMENTS(z4)), $
      $;row 5
      FieldProcessing               : STRARR(N_ELEMENTS(z5)), $
      $;row 6
      FieldDataTypes                : STRARR(N_ELEMENTS(z6))}
      
    ;row 1
    FOR i=0,7 DO TOB3_hdr.(i) = STRMID(z1[i],1,STRLEN(z1[i])-2)
    
    ;row 2
    FOR i=0,1 DO TOB3_hdr.(i+8) = STRMID(z2[i],1,STRLEN(z2[i])-2)
    FOR i=2,4 DO TOB3_hdr.(i+8) = LONG(STRMID(z2[i],1,STRLEN(z2[i])-2))
    ;removes the nonsensical ""
    TOB3_hdr.(13) = STRMID(z2[5],1,STRLEN(z2[5])-2) & TOB3_hdr.(14) = LONG(STRMID(z2[6],1,STRLEN(z2[6])-2))
    
    ;row 3-6,removes the nonsensical "" around the fieldnames/unis/processing/datatypes
    FOR i=0,N_ELEMENTS(z3)-1 DO TOB3_hdr.FieldNames[i]      = STRMID(z3[i],1,STRLEN(strtrim(z3[i],2))-2)
    FOR i=0,N_ELEMENTS(z4)-1 DO TOB3_hdr.FieldUnits[i]      = STRMID(z4[i],1,STRLEN(strtrim(z4[i],2))-2)
    FOR i=0,N_ELEMENTS(z5)-1 DO TOB3_hdr.FieldProcessing[i] = STRMID(z5[i],1,STRLEN(strtrim(z5[i],2))-2)
    FOR i=0,N_ELEMENTS(z6)-1 DO TOB3_hdr.FieldDataTypes[i]  = STRMID(z6[i],1,STRLEN(strtrim(z6[i],2))-2)
    
  end
  FUNCTION byte_to_FP2, BYTEVAL
  
    ;BYTEVAL contains the two bytes of the FP2 value
    ;Output is a IDL double precision datatype of the FP2 value
  
    ;- check input data
    if n_elements(BYTEVAL[*,0]) ne 2 then stop, 'ERROR: n_elements(BYTEVAL[*,0]) ne 2'
    n_rcd = n_elements(BYTEVAL[0,*])
    
    ;- create integer from byte values
    fs_word = ishft(fix(BYTEVAL[0,*]), 8) + BYTEVAL[1,*]
    
    ;- create some fixed values
    pos_infinity = make_array(n_rcd, /integer, value='1fff'x)
    neg_infinity = make_array(n_rcd, /integer, value='9fff'x)
    not_a_number = make_array(n_rcd, /integer, value='9ffe'x)
    
    ;- extract specific bits
    is_negative = ((fs_word and '8000'x) ne 0)
    mantissa = fix(fs_word and '1FFF'x)
    exponent = fix(ishft(fs_word and '6000'x, -13))
    
    ;- calculate the floating point value
    RTN = dblarr(n_rcd)
    pos_inf = where(fs_word eq pos_infinity)
    neg_inf = where(fs_word eq neg_infinity)
    nan = where(fs_word eq not_a_number)
    residual = where(fs_word ne pos_infinity and fs_word ne neg_infinity and fs_word ne not_a_number)
    is_neg = where(is_negative ne 0 and mantissa ne 0)
    
    if pos_inf[0] ne -1 then RTN[pos_inf] = !values.F_INFINITY
    if neg_inf[0] ne -1 then RTN[neg_inf] = -1.0*!values.F_INFINITY
    if nan[0] ne -1 then RTN[nan] = !values.F_NAN
    if residual[0] ne -1 then begin
      RTN[residual] = mantissa[residual]*10^(-1.0*exponent[residual])
      if is_neg[0] ne -1 then RTN[is_neg] *= -1.0
    endif
    
    ;- return the floating point value
    return, RTN
  ;C++ SOURCECODE FROM http://www.campbellsci.com/forum/messages.cfm?threadid=C79B9654-CA88-4D06-67B35460B7BF6B50
  ;
  ;<pre>
  ;typedef unsigned char byte;
  ;typedef unsigned short uint2;
  ;float csiFs2ToFloat(void const *buff_)
  ;{
  ;// we are going to cast the binary value into a two byte integer so that it is convenient to pick
  ;// out patterns and pick off parts of the structure.
  ;byte const *buff = static_cast<byte const *>(buff_);
  ;uint2 fs_word = (uint2(buff[0]) << 8) + buff[1];
  ;// we can now pick off the components of the FS2 structure
  ;static uint2 const pos_infinity = 0x1fff;
  ;static uint2 const neg_infinity = 0x9fff;
  ;static uint2 const not_a_number = 0x9ffe;
  ;bool is_negative = ((fs_word & 0x8000) != 0);
  ;uint2 mantissa = fs_word & 0x1FFF;
  ;uint2 exponent = (fs_word & 0x6000) >> 13;
  ;double rtn;
  ;if(fs_word == pos_infinity)
  ;rtn = std::numeric_limits<float>::infinity();
  ;else if(fs_word == neg_infinity)
  ;rtn = -1.0f * std::numeric_limits<float>::infinity();
  ;else if(fs_word == not_a_number)
  ;rtn = std::numeric_limits<float>::quiet_NaN();
  ;else
  ;{
  ;rtn = static_cast<float>(mantissa);
  ;for(uint2 i = 0; mantissa != 0 && i < exponent; ++i)
  ;rtn /= 10.0f;
  ;if(is_negative && mantissa != 0)
  ;rtn *= -1.0f;
  ;}
  ;return static_cast<float>(rtn);
  ;} // csiFs2ToFloat
  ;</pre>
  END
  
  
  function string2time,x
    ;Typical Values is apparently a thing in the description of csi file formats.
    ;with only two entrys, namely these are MSEC and USEC for micro, respectively nano
    ; I (RS) added SEC also which is just 1 and the else as 1 too since no other cases are known to me
    case strupcase(x) of
      'MSEC': y=1E3
      'USEC': y=1E6
      'SEC': y=1E0
      else: y=1E0
    endcase
    return,y
  end
  
  function sec1990_tojday,x
    return, x/(86400D)+julday(1,1,1990,0,0,0)
  end
  function sec1970_tojday,x
    return, x/(86400D)+julday(1,1,1970,0,0,0)
  end
  function julday2sec1990,x
    return, (x-julday(1,1,1990,0,0,0))*(86400D)
  end
  function julday2sec1970,x
    return, (x-julday(1,1,1970,0,0,0))*(86400D)
  end
  
  ;######################################FILE-READER##########################
  
  ;+
  ; :Description:
  ;   Reads TOB3-Files:
  ;   TOB3 has 2 main elements with 3 subelements for the second
  ;   First main is header, can be read ASCII and has 512 bytes
  ;   Second is Frames, containing data as follows
  ;   A Frameheader of 12 bytes as 3 Longs, then Databytes (amount taken from hdr) depending on samples, then Framefoot with 4 Bytes as 2 UINT
  ;   This yields: (12 BYTE framehdr+ DATA + 4 framefoot)*N EOF with N as number of records and EOF as end of file
  ;   Framesize is given in HDR as third entry on second line. For data in frame, subtract header and footer
  ;   Possible Datatypes in frame are:FP2 = 2 Byte, IEEE4 = 4 Byte as Float, INT4 =
  ;
  ; :Procedure:
  ;   After hdr, reading data is done frame by frame and validation between footer and validationstamp from header.
  ;   If validation does not match, datavalues are set to NAN.
  ;   After all data are read in, results are returned as STRUCTURE with hdr and data separates.
  ;   (Reduction of dataamount possible, see Keywords)
  ;
  ; :Changelog and Notes:
  ;   9.4.2013 FP2 not implented yet. Samplingrate done by constant, needs adaption by checking hdr
  ;   24.9.2014 Able to read AScii and FP2 now. Samplingrate taken from header, depends obviously on proper documentation in header
  ;   20.5.2015 Fixed the missing swap endian for integer (type eq 3)
  ;   1.7.2015 After three days due to bad CSI documentation hopefully the last time an edit is necessary.
  ;
  ; :Keywords:
  ;  quiet: no message during file readin
  ;  validation: basic check at the end for record numbering in the file (i.e. if records are sorted ascending [which should be done by the routine anyway, so slightly moot])
  ;  nojulday: default is to report julday and recordnumber, however the file contains seconds passed since midnight 1.1.1990 (unix-elapsed seconds similar)
  ;
  ;
  ; :Dependencies:
  ;   SWAP_ENDIAN (could be done by BYTE_ORDER as well)
  ;
  ;
  ; :Author: spirro00
  ;-
  function get_tob3_data, file,quiet=quiet,validation=validation,seperate_time=seperate_time,nojulday=nojulday,timestampwarning=timestampwarning
    ;Some parameters of TOB3 and file
    fhdr=12 &  ffoot=4 & info=FILE_INFO(file) & filesize=info.size
    IEEE4=0 & INT4=0 & ASCII=0 & FP2=0. & Other=0
    if ~KEYWORD_SET(resolution) then resolution=1000D ; MSec resolution
    ;Get hdr
    get_tob3_header,file,hdr,pos
    
    ;Open file and set to after hdr
    OPENR,lun,file,/GET_LUN &  POINT_LUN,lun,pos
    
    ;check datatypes, so far only IEEE4/INT4/FP2/ASCII allowed
    datatypes=hdr.fielddatatypes
    cont=1 & type=0. & x=0
    for i=0,N_ELEMENTS(datatypes)-1 do begin
      if i gt 0 then if (strmatch(datatypes[i],datatypes[i-1]) and ~STRMATCH(DATATYPES[i],'ASCII*'))  then begin
        cont[x]+=1
      endif else begin
        cont=[cont,1]
        type=[type,0]
        x++
      endelse
      
      if strmatch(DATATYPES[i],'IEEE4*') then begin
        IEEE4++ & type[x]=4
      endif else begin
        if strmatch(DATATYPES[i],'INT4*') then begin
          INT4++ & type[x]=3
        endif else begin
          if STRMATCH(datatypes[i],'FP2*') then begin
            FP2++ & type[x]=16 ;introducing type 16 for fp2, will be read in as byte, transformed later
          endif else begin
            if STRMATCH(DATATYPES[i],'ASCII*') then begin
              ascii++
              y=strsplit(strsplit(strmid(DATATYPES[I],5,4),'(',/extract),')',/extract)
              
              if type[x] ge 7. then type[x]+=float(y)*0.001 else type[x]=7. + float(y)*0.001
            endif else begin
              other++
            endelse
          endelse
        endelse
      endelse
      
      
    endfor
    if (other) gt 0. then MESSAGE,'Error in Datatypes, only IEEE4, INT4 allowed'
    
    ;Some more parameters concerning validation, datasize in frame and remaining frames.
    framesize=hdr.dataframesize & validation=hdr.validationstamp &  datrecsize=(FRAMESIZE-ffoot-fhdr) &  rem_file=(filesize-pos)
    if total(where(type ge 7 and type lt 8.)) ne -1 then asclen=round(total(type[where(type ge 7 and type lt 8.)]-7.)*1000) else asclen=0
    if (fp2+IEEE4+int4) ne 0 then fltlen=IEEE4*4+int4*4.+fp2*2. else fltlen=0
    nrec=datrecsize/(fltlen+(asclen))
    
    
    ;Setting up data container, string is seperate, since string is just plain stupid.
    timerec=dblarr(2,(rem_file)/framesize*(nrec))-!VALUES.F_NAN
    subtimerec=dblarr((rem_file)/framesize*(nrec))-!VALUES.F_NAN
    retain=dblarr(3,(rem_file)/framesize)-!VALUES.F_NAN
    if fltlen ne 0  then data=fltarr(IEEE4+int4+fp2,(rem_file/framesize*(nrec)))-!VALUES.F_NAN
    if ascii ne 0 then ascDATA=STRARR(ASCII,(rem_file)/framesize*(nrec))+' '
    
    ;Read in variables, hh = header (time+subseconds+recordnumber), ff =footer (validation of the datarecords)
    hh=lonarr(3)-1L & ff=[0U,0U] &   i=0D
    ;How many records we have to expect in a frame (fltlen+asclen gives us the amount in bits)
    datframerec=(int4+ieee4+fp2)
    if ASCII ne 0 then datframerec+=1.*round(total(type[where(type ge 7 and type lt 8.)]-7.)*1000.)
    
    
    if strcmp(strmid(hdr.frametimeresolution,0,3),'sec',/FOLD_CASE) ne 1 then stop
    rec_resolution=strmid(hdr.frametimeresolution,3,strlen(hdr.frametimeresolution)-3)
    rec_res_fact=DOUBLE(strmid(REC_RESOLUTION,0,min(where(byte(REC_RESOLUTION) gt 65))))
    rec_resolution=strmid(REC_RESOLUTION,min(where(byte(REC_RESOLUTION) gt 65)))
    rec_resolution=string2time(rec_resolution)
    subrec_scaling=(rec_res_fact/REC_RESOLUTION)
    
    subrec_resolution=DOUBLE(strmid(hdr.NON_TIMESTAMPEDRECORDINTERVAL,0,strpos(hdr.NON_TIMESTAMPEDRECORDINTERVAL,' ')))
    subrec_fac= strmid(hdr.NON_TIMESTAMPEDRECORDINTERVAL,strpos(hdr.NON_TIMESTAMPEDRECORDINTERVAL,' ')+1)
    
    subrec_fac=string2time(subrec_fac)
    
    subrec_interval=(subrec_resolution/subrec_fac)
    subrec_step=(subrec_fac/rec_res_fact*subrec_resolution)
    
    ;Data read in
    mf=0D & ret_i=0D
    len=fltlen+asclen & inframe=uintarr((framesize)/2.)
    
    ;Timecheck
    POINT_LUN,-lun,posx & readu,lun,hh  & POINT_LUN,lun,posx
    ctime=float(strmid(hdr.filecreationtime,[0,5,8,11,14,17],[4,2,2,2,2,2]))
    ctime=round(julday2sec1990(julday(ctime[1],ctime[2],ctime[0],ctime[3],ctime[4],ctime[5])))
    tchk=round(( (double(hh[0])+hh[1]*subrec_scaling)-ctime))
    if abs(tchk) ge  30. then begin  ;offset in x times seconds is allowed, where x is here 10
      MESSAGE,'Warning: Filecreation time (HDR) and first timerecord diverge by '+strtrim(string(abs(tchk)),2)+' seconds',/CONTINUE
      MESSAGE,'File: '+FILE,/CONTINUE
    endif
    
    
    
    ;*******starting with data readin***********
    while ~eof(lun) do begin
    
      retain[*,ret_i++]=hh
      POINT_LUN,-lun,posx
      readu,lun,hh
      
      POINT_LUN,lun,posx
      readu,lun,inframe
      ;*********normal data handling if ff (=last 2 elements of inframe) is equal the validation (from header)*********
      if inframe[N_ELEMENTS(inframe)-1] ne (2U^16-1)-VALIDATION and inframe[N_ELEMENTS(inframe)-1] ne VALIDATION then continue
      if inframe[N_ELEMENTS(inframe)-2] eq 0 then begin
        subrec=nrec
        rr=1
        
      endif else begin
        ; ******** Minor Frame - Find out how long with the second footer hidden in the major frame (where)*****
        ;
        ; IF THE Normal Footer (ff[0]) is actually usable for the bit-decomposition into minor frames
        ; as done for the second footer in this minor frame we could uncomment the following and escape somewhat earlier.
        ; Since the CSI Manual for this is however the last garbage, we err on the cautious side for now and check anyway.
        ;
        ;      chk= N_ELEMENTS(inframe)-1
        ;      bits=strmid(string(inframe[chk],format='(B)'),indgen(16),[intarr(16)+1])
        ;      if total(strcmp(bits,' ')) ne 0 then bits[where(strcmp(bits,' ') eq 1)]='0'
        ;       if strcmp(bits[1],'1') eq 1 then continue
        ;      stop
        chk=where(inframe[0:N_ELEMENTS(inframe)-3] eq VALIDATION or inframe[0:N_ELEMENTS(inframe)-3] eq (2U^16-1)-VALIDATION,cnt)-1
        if cnt eq 0 then continue
        offset_calc=2U^ [11U-uindgen(12)]
        bits=strmid(string(inframe[chk],format='(B)'),indgen(16),[intarr(16)+1])
        if total(strcmp(bits,' ')) ne 0 then bits[where(strcmp(bits,' ') eq 1)]='0'
        size_offset=total(bits[4:*]*offset_calc)-FFOOT-FHDR
        ;if SIZE_OFFSET mod (fltlen+asclen) ne 0 then size_offset=total(bits[4:*]*offset_calc)
        ;bits[0]=Minor
        ;bits[1]=Empty
        ;bits[2]=x /reserved/unused
        ;bits[3]=File Mark
        ;print, bits[0:3]
        if strcmp(bits[1],'1') eq 1 then continue
        if strcmp(bits[0],'1') eq 1 then begin
          subrec=SIZE_OFFSET/(fltlen+ASCLEN)
          if subrec le 0. then rr=0 else rr=1
        ; print, bits[0:3]
        endif else rr=0
        POINT_LUN,-LUN,ENDFRAME
        
      endelse
      
      
      if rr eq 1 then begin
      
        ; **** rr = 1 tells us to read in data *********
        dd=-0.0001
        ee=' '
        POINT_LUN,lun,posx
        readu,lun,hh
        
        
        
        ;***** if not for strings, we could read in data quicker by combining container for all subrecs****
        for iii=0,subrec[0]-1 do begin
          for ii=0,N_ELEMENTS(cont)-1 do begin
          
            ftype=floor(type[ii])
            case ftype of
              16: aa=MAKE_ARRAY(2.*cont[ii],TYPE=1.)
              7:aa=strarr(ROUND((TYPE[II]-7.)*1000.))+' '
              else: aa=MAKE_ARRAY(cont[ii],TYPE=type[ii])
            endcase
            
            readu,lun,aa
            ;Swapping data
            if ftype ne 7. then BEGIN
            
              if ftype eq 4.  or ftype eq 3. then aa=SWAP_ENDIAN(aa)
              if ftype eq 16. then begin
                bb=dblarr(N_ELEMENTS(aa)/2)
                for bit=0,(cont[ii])*2.-1,2 do  bb[bit/2.]=byte_to_FP2(aa[bit:bit+1])
                aa=bb
              endif
              
              if (TOTAL(SIZE(DD)) eq 0) then dd=aa else if (dd[0] eq -0.0001) then dd=aa else dd=[dd,aa]
              
            ENDIF ELSE BEGIN
            
              if asclen ne 0 then begin
                if total(size(ee)) eq 0  then EE=strjoin(aa) else  if strmatch(ee[0],' ') then ee=strjoin(aa) else  EE=[EE,strjoin(aa)]
                
              endif
              
            ENDELSE
          endfor
        endfor
        
        if fltlen ne 0 then data[*,mf:subrec-1+mf]=dd
        if asclen ne 0 then ascdata[*,mf:subrec-1+mf]=ee
        timerec[1,mf:subrec-1+mf]=dindgen(subrec)+hh[2]
        timerec[0,mf:subrec-1+mf]=DOUBLE(hh[0])
        
        subtimerec[mf:subrec-1+mf]=dindgen(subrec)*subrec_interval+DOUBLE(hh[1])*SUBREC_SCALING
        ;print, hh[1]
        mf+=subrec
        
      endif
      if subrec ne nrec or rr eq 0 then POINT_LUN,LUN,ENDFRAME-ffoot
      readu,lun,ff
      POINT_LUN,-lun,posi
      
      rr=0
      i++
      
    endwhile
    
    
    
    
    
    
    ;closing file
    close,lun &  FREE_LUN,lun
    
    timerec=timerec[*,0:mf-1]
    if fltlen ne 0 then data=data[*,0:mf-1]
    if asclen ne 0 then ASCDATA=ASCDATA[*,0:mf-1]
    
    timerec[0,*]=timerec[0,*]
    if ~KEYWORD_SET(seperate_time) then  timerec[0,*]+=subtimerec else seperate_time=seperate_time
    
    
    ;sorting
    x=dindgen(N_ELEMENTS(timerec[1,*]))+min(timerec[1,0],/nan)
    if stddev(x-timerec[1,*],/nan) ne 0 then begin
      if ~KEYWORD_SET(quiet) then MESSAGE,'Sorting by record (required by filestructures)', /continue
      sorting=sort(timerec[1,*])
      for i=0,1 do timerec[i,*]=timerec[i,sorting]
      if KEYWORD_SET(seperate_time) then seperate_time=seperate_time[sorting]
      if fltlen ne 0 then for i=0,N_ELEMENTS(data[*,0])-1 do data[i,*]=data[i,sorting]
      if asclen ne 0 then for i=0,N_ELEMENTS(ascdata[*,0])-1 do ascdata[i,*]=ascdata[i,sorting]
    endif
    
    ;do some data validation at least.
    if KEYWORD_SET(validation) then begin
      if total(size(data)) ne 0 then for i=0,N_ELEMENTS(data[*,0])-1 do $
        chk=HISTOGRAM(data[i,*],/nan,nbins=10000.< N_ELEMENTS(data[i,*]),loca=loca)
        
    endif
    
    ;convert passed seconds since 1.1.1990 to jdays
    if ~KEYWORD_SET(nojulday) then if KEYWORD_SET(seperate_time) then $
      timerec[0,*]=sec1990_tojday(timerec[0,*]+seperate_time) else $
      timerec[0,*]=sec1990_tojday(timerec[0,*])
      
    ;Creates structure for the data with 0 = hdr, 1 = data
    content=create_struct('meta',hdr,'TimeRec',timerec)
    if fltlen ne 0 then content=CREATE_STRUCT(content,'data', data)
    IF ASCLEN NE 0 THEN content=CREATE_STRUCT(content,'ascdata', ASCdata)
    
    ;Returns data
    return,content
    
    
  end
  
