function respMCS = responseMCS(edcaMAC, frameFormat, chanWidth, aggregatedMPDU, mcs, numTxChains)
%responseMCS Return the MCS to be used for sending response frame
%   RESPMCS = responseMCS(EDCAMAC, FRAMEFORMAT, CHANWIDTH, ...
%   AGGREGATEDMPDU, MCS, NUMTXCHAINS) returns the MCS index to be used for
%   the response frame.
%
%   RESPMCS is an integer specifying the MCS index for the response frame.
%
%   EDCAMAC is the MAC layer object, of type hEDCAMAC.
%
%   FRAMEFORMAT is a value of type hFrameFormats, specifying the format
%   of the frame soliciting the response.
%
%   CHANWIDTH is an integer specifying the channel bandwidth of the frame
%   soliciting the response.
%
%   AGGREGATEDMPDU is the flag indicating if the frame soliciting the
%   response is aggregated.
%
%   MCS is the MCS index of the frame soliciting the response.
%
%   NUMTXCHAINS is an integer representing the number of transmit chains
%   used for the frame soliciting the response.

%   Copyright 2021 The MathWorks, Inc.

cbw = hEDCAMAC.getChannelBandwidthStr(chanWidth);

switch frameFormat
    case hFrameFormats.NonHT
        respMCS = max(edcaMAC.BasicRatesIndexes(edcaMAC.BasicRatesIndexes <= mcs));
        
    case hFrameFormats.HTMixed
        edcaMAC.HTConfig.ChannelBandwidth = cbw;
        edcaMAC.HTConfig.AggregatedMPDU = aggregatedMPDU;
        edcaMAC.HTConfig.MCS = mcs;
        edcaMAC.HTConfig.NumTransmitAntennas = numTxChains;
        edcaMAC.HTConfig.NumSpaceTimeStreams = numTxChains;
        
        r = wlan.internal.getRateTable(edcaMAC.HTConfig);
        symbolTime = 4; % in microseconds
        rxRate = r.NDBPS/symbolTime;
        % Response frame MCS
        respMCS = max(edcaMAC.BasicRatesIndexes(edcaMAC.BasicRates <= rxRate));
        
    case hFrameFormats.VHT
        edcaMAC.VHTConfig.ChannelBandwidth = cbw;
        edcaMAC.VHTConfig.MCS = mcs;
        edcaMAC.VHTConfig.NumTransmitAntennas = numTxChains;
        edcaMAC.VHTConfig.NumSpaceTimeStreams = numTxChains;
        
        r = wlan.internal.getRateTable(edcaMAC.VHTConfig);
        symbolTime = 4; % in microseconds
        rxRate = r.NDBPS(1)/symbolTime;
        % Response frame MCS
        respMCS = max(edcaMAC.BasicRatesIndexes(edcaMAC.BasicRates <= rxRate));
        
    otherwise % HE-SU/HE-EXT-SU format
        edcaMAC.HESUConfig.ChannelBandwidth = cbw;
        edcaMAC.HESUConfig.MCS = mcs;
        edcaMAC.HESUConfig.ExtendedRange = (frameFormat == hFrameFormats.HE_EXT_SU);
        edcaMAC.HESUConfig.NumTransmitAntennas = numTxChains;
        edcaMAC.HESUConfig.NumSpaceTimeStreams = numTxChains;
        
        [~, r] = wlan.internal.heCodingParameters(edcaMAC.HESUConfig);
        symbolTime = 16; % in microseconds
        rxRate = r.NDBPS/symbolTime;
        % Response frame MCS
        respMCS = max(edcaMAC.BasicRatesIndexes(edcaMAC.BasicRates <= rxRate));
end
end
