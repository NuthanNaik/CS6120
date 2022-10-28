function updateNAV(edcaMAC, entryTimestamp)
%updateNAV Updates intra-NAV, inter-NAV and NAV
%   updateNAV(EDCAMAC, ENTRYTIMESTAMP) updates intra-NAV and inter-NAV when
%   spatial reuse is enabled and updates NAV when spatial reuse is not
%   enabled.
%
%   EDCAMAC is an object of type hEDCAMAC. 
%
%   ENTRYTIMESTAMP is the entry timestamp of state/sub-state in which this
%   function is called.

%   Copyright 2021 The MathWorks, Inc.

% Update intra-NAV and inter-NAV when spatial reuse operation is enabled
if edcaMAC.EnableSROperation
    edcaMAC.IntraNAV = max(edcaMAC.IntraNAV - (getCurrentTime(edcaMAC) - entryTimestamp), 0);
    edcaMAC.InterNAV = max(edcaMAC.InterNAV - (getCurrentTime(edcaMAC) - entryTimestamp), 0);
else
    edcaMAC.NAV = max(edcaMAC.NAV - (getCurrentTime(edcaMAC) - entryTimestamp), 0);
end
end
