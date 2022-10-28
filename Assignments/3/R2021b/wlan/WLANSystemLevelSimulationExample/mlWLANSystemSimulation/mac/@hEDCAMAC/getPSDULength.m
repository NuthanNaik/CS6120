function [psduLength, mpduLengths, subframeLengths] = getPSDULength(edcaMAC)
%getPSDULength Returns PSDU length in octets
%
%   [PSDULENGTH, MPDULENGTHS, SUBFRAMELENGTHS] = getPSDULength(EDCAMAC)
%   returns the length of the PSDU, MPDUs and Subframes based on the
%   transmission frame dequeued from MAC queues.
%
%   PSDULENGTH is 9-by-1 vector, indicates the length of PSDU in octets.
%
%   MPDULENGTHS is a n-by-1 vector, indicates the length of each MPDU in
%   octets. Here, n indicates the maximum number of subframes.
%
%   SUBFRAMELENGTHS is a n-by-1 vector, indicates the length of each A-MPDU
%   subframe in octets. Here, n indicates the maximum number of subframes.
%
%   EDCAMAC is an object of type hEDCAMAC.

%   Copyright 2021 The MathWorks, Inc.

% QoS Data MAC header and FCS (30 Bytes)
psduLength = zeros(9, 1);
mpduLengths = zeros(edcaMAC.MaxSubframes, 9);
subframeLengths = zeros(edcaMAC.MaxSubframes, 9);

for userIdx = 1:edcaMAC.NumTxUsers
    for i = 1:edcaMAC.Tx.TxFrame(userIdx).MSDUCount
        if edcaMAC.Tx.TxFrame(userIdx).FourAddressFrame(i)
            % MPDU overhead with mesh control
            mpduOverhead = 36;
        else
            % MPDU overhead
            mpduOverhead = 30;
        end
        % Calculate MPDU length
        mpduLengths(i, userIdx) = (mpduOverhead + edcaMAC.Tx.TxFrame(userIdx).MSDULength(i));
        subframeLengths(i, userIdx) = mpduLengths(i, userIdx);
        
        % Calculate PSDU length
        psduLength(userIdx) = psduLength(userIdx) + mpduLengths(i, userIdx);
        
        % Aggregated MPDU
        if edcaMAC.MPDUAggregation
            % Delimiter overhead for aggregated frames (4 Octets)
            psduLength(userIdx) = psduLength(userIdx) + 4;
            subframeLengths(i, userIdx) = subframeLengths(i, userIdx) + 4;
            
            % Subframe padding overhead for aggregated frames
            subFramePadding = abs(mod(edcaMAC.Tx.TxFrame(userIdx).MSDULength(i)+mpduOverhead, -4));
            % Last subframe doesn't have padding in case of HT A-MPDU
            if (i == edcaMAC.Tx.TxFrame(userIdx).MSDUCount) && (edcaMAC.TxFormat == hFrameFormats.HTMixed)
                subFramePadding = 0;
            end
            psduLength(userIdx) = psduLength(userIdx) + subFramePadding;
            subframeLengths(i, userIdx) = subframeLengths(i, userIdx) + subFramePadding;
        end
    end
end
end
