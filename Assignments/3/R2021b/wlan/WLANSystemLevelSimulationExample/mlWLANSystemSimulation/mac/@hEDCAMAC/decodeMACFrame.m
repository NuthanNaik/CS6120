function [macConfig, macPayload, isValid] = decodeMACFrame(edcaMAC, frame, format, mpduDatatype)
%decodeMACFrame Decodes the given MAC frame
%
%   [MACCONFIG, MACPAYLOAD, ISVALID]= decodeMACFrame(EDCAMAC, FRAME, FORMAT,
%   MPDUDATATYPE) decodes the given MAC frame.
%   
%   MACCONFIG is a structure of type hEDCAMAC.EmptyMACConfig, indicates the
%   MAC frame configuration containing the decoded MAC parameters.
%
%   MACPAYLOAD represents the payload present in received MAC frame.
%
%   ISVALID is logical value which indicates whether the received frame
%   passed the FCS check.
%
%   EDCAMAC is an object of type hEDCAMAC.
%
%   FRAME represents the MAC frame received with header and payload
%   information.
%
%   FORMAT specifies the received frame format
%
%   MPDUDATATYPE represents the datatype of the input frame. It can be
%   either 0 or 1. 0 indicates datatype bits and 1 indicates datatype is
%   octets.

%   Copyright 2021 The MathWorks, Inc.

if mpduDatatype
  dataFormat = 'octets';
else
  dataFormat = 'bits';
end

if (format == hFrameFormats.HE_EXT_SU)
    edcaMAC.HESUConfig.ExtendedRange = true;
end

% Decode the MPDU
if isempty(frame)
    % For empty MPDU considering it as decode failure and assigning default
    % values
    status = wlanMACDecodeStatus.NotEnoughData;
    hexPayload = {};
elseif format == hFrameFormats.NonHT
    [macConfig, hexPayload, status] = wlanMPDUDecode(frame, edcaMAC.NonHTConfig, 'DataFormat', dataFormat);
elseif format == hFrameFormats.HTMixed
    [macConfig, hexPayload, status] = wlanMPDUDecode(frame, edcaMAC.HTConfig, 'DataFormat', dataFormat);
elseif format == hFrameFormats.VHT
    [macConfig, hexPayload, status] = wlanMPDUDecode(frame, edcaMAC.VHTConfig, 'DataFormat', dataFormat);
else % HE format
    [macConfig, hexPayload, status] = wlanMPDUDecode(frame, edcaMAC.HESUConfig, 'DataFormat', dataFormat);
end

% Initialize
macPayload = uint8([]); % For codegen
isValid = false;

% Valid MPDU
if status == wlanMACDecodeStatus.Success
    if numel(hexPayload)
        % MAC payload
        macPayload = uint8(hex2dec(hexPayload{1}));
    end
    isValid = true;
end

% Initialize empty MAC frame configuration, if received frame is invalid
if ~isValid
    macConfig = edcaMAC.EmptyMACConfig;
end
end



