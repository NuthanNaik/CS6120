function duration = calculateTxTime(edcaMAC, cbw, mcs, psduLength, frameFormat, numSTS)
%calculateTxTime Calculates the physical layer protocol data unit (PPDU)
%transmission time
%
%   DURATION = calculateTxTime(EDCAMAC, CBW, MCS, PSDULENGTH, FRAMEFORMAT)
%   returns the transmission time for the PPDU.
%
%   DURATION is an integer, indicates the duration to transmit PPDU in
%   microseconds.
%
%   EDCAMAC is an object of type hEDCAMAC.
%
%   CBW is an integer, indicates the channel bandwidth used for
%   transmitting the MAC frame.
%
%   MCS is an integer, indicates the PHY data rate for transmitting the
%   MAC frame.
%
%   PSDULENGTH is an integer, indicates the length of the PSDU in bytes.
%
%   FRAMEFORMAT specifies the format of the PSDU to be transmitted. It is a
%   constant value of type hFrameFormats.
%   
%   NUMSTS is an integer, indicates the number of spatial streams used for
%   transmitting the MAC frame.

%   Copyright 2021 The MathWorks, Inc.

tx = edcaMAC.Tx; % Tx context
cbwStr = hEDCAMAC.getChannelBandwidthStr(cbw); % Channel bandwidth

switch frameFormat
    case hFrameFormats.HTMixed
        % HT format configuration object
        tx.CfgHT.ChannelBandwidth = cbwStr;
        tx.CfgHT.MCS = mcs;
        tx.CfgHT.NumTransmitAntennas = numSTS;
        tx.CfgHT.NumSpaceTimeStreams = numSTS;
        tx.CfgHT.PSDULength = psduLength;
        
        % Get PPDU info
        ppduInfo = validateConfig(tx.CfgHT);
        
    case hFrameFormats.VHT
        % VHT format configuration object
        tx.CfgVHT.ChannelBandwidth = cbwStr;
        tx.CfgVHT.MCS = mcs;
        tx.CfgVHT.NumTransmitAntennas = numSTS;
        tx.CfgVHT.NumSpaceTimeStreams = numSTS;
        tx.CfgVHT.APEPLength = psduLength;
        
        % Get PPDU info
        ppduInfo = validateConfig(tx.CfgVHT);
        
    case {hFrameFormats.HE_SU, hFrameFormats.HE_EXT_SU}
        % HE format configuration object
        tx.CfgHE.ChannelBandwidth = cbwStr;
        tx.CfgHE.ExtendedRange = false;
        if frameFormat == hFrameFormats.HE_EXT_SU
            tx.CfgHE.ExtendedRange = true;
        end
        tx.CfgHE.MCS = mcs;
        tx.CfgHE.NumTransmitAntennas = numSTS;
        tx.CfgHE.NumSpaceTimeStreams = numSTS;
        tx.CfgHE.APEPLength = psduLength;
        
        % Get PPDU info
        ppduInfo = validateConfig(tx.CfgHE);
        
    otherwise % Non-HT
        % Non-HT format configuration object
        tx.CfgNonHT.ChannelBandwidth = cbwStr;
        tx.CfgNonHT.MCS = mcs;
        tx.CfgNonHT.NumTransmitAntennas = numSTS;
        tx.CfgNonHT.PSDULength = psduLength;
        
        % Get PPDU info
        ppduInfo = validateConfig(tx.CfgNonHT);
end

% Tx time of the PPDU
duration = ppduInfo.TxTime;
end
