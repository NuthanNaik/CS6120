function maxPSDULength = getMaxPSDULength(edcaMAC)
%getMaxPSDULength Calculates the maximum allowed PSDU length in bytes
%
%   MAXPSDULENGTH = getMaxPSDULength(EDCAMAC) returns the maximum allowed
%   PSDU length that can be transmitted within 5484 microseconds (maximum
%   duration limit of a PPDU).
%
%   MAXPSDULENGTH is an integer, indicates the maximum length of PSDU in
%   bytes.
%
%   EDCAMAC is an object of type hEDCAMAC.

%   Copyright 2021 The MathWorks, Inc.

tx = edcaMAC.Tx; % Tx context
maxTxTime = 5484; % Maximum duration limit of a PPDU in microseconds
cbwStr = hEDCAMAC.getChannelBandwidthStr(edcaMAC.AvailableBandwidth); % Channel bandwidth

% HT-Mixed format A-MPDU
switch edcaMAC.TxFormat
    case hFrameFormats.NonHT
        psduLength = 4095;
        
    case hFrameFormats.HTMixed
        % Fill HT config object
        tx.CfgHT.ChannelBandwidth = cbwStr;
        tx.CfgHT.AggregatedMPDU = edcaMAC.MPDUAggregation;
        tx.CfgHT.MCS = edcaMAC.Tx.TxMCS(edcaMAC.UserIndexSU);
        tx.CfgHT.NumTransmitAntennas = edcaMAC.NumTxChains;
        tx.CfgHT.NumSpaceTimeStreams = edcaMAC.NumTxChains;
        maxSymbolTime = 4;
        
        % To avoid symbol padding and exceeding maximum transmission time, PSDU
        % length is calculated for a symbol time less than the maxTxTime
        psduLen = wlanPSDULength(tx.CfgHT, 'TxTime', maxTxTime-maxSymbolTime);
        
        % Maximum length allowed by the standard
        if psduLen > 65535
            psduLength = 65535;
        else
            psduLength = psduLen;
        end
        
        % VHT format A-MPDU
    case hFrameFormats.VHT
        % Fill VHT config object
        tx.CfgVHT.ChannelBandwidth = cbwStr;
        tx.CfgVHT.MCS = edcaMAC.Tx.TxMCS(edcaMAC.UserIndexSU);
        tx.CfgVHT.NumTransmitAntennas = edcaMAC.NumTxChains;
        tx.CfgVHT.NumSpaceTimeStreams = edcaMAC.NumTxChains;
        maxSymbolTime = 4;
        
        % To avoid symbol padding and exceeding maximum transmission time, PSDU
        % length is calculated for a symbol time less than the maxTxTime
        psduLen = wlanPSDULength(tx.CfgVHT, 'TxTime', maxTxTime-maxSymbolTime);
        
        % Maximum length allowed by the standard
        if psduLen > 1048575
            psduLength = 1048575;
        else
            psduLength = psduLen;
        end
        
        % HE-SU/HE-EXT-SU format A-MPDU
    case {hFrameFormats.HE_EXT_SU, hFrameFormats.HE_SU}
        % Fill HE config object
        tx.CfgHE.ExtendedRange = (edcaMAC.TxFormat == hFrameFormats.HE_EXT_SU);
        tx.CfgHE.ChannelBandwidth = cbwStr;
        tx.CfgHE.MCS = edcaMAC.Tx.TxMCS(edcaMAC.UserIndexSU);
        tx.CfgHE.NumTransmitAntennas = edcaMAC.NumTxChains;
        tx.CfgHE.NumSpaceTimeStreams = edcaMAC.NumTxChains;
        maxSymbolTime = 16;
        
        % To avoid symbol padding and exceeding maximum transmission time, PSDU
        % length is calculated for a symbol time less than the maxTxTime
        psduLen = wlanPSDULength(tx.CfgHE, 'TxTime', maxTxTime-maxSymbolTime);
        
        % Maximum length allowed by the standard
        if psduLen > 6500631
            psduLength = 6500631;
        else
            psduLength = psduLen;
        end
end
maxPSDULength = psduLength(1);
end
