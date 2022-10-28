function [txs,rxs] = hCreateSitesFromNodes(nodeConfigs)
%createSitesFromNodes Create transmitter and receiver sites
%   [TXS,RXS] = hCreateSitesFromNodes(NODECONFIGS) returns transmitter and
%   receiver sites for the given NumNodes length node configuration
%   structure array NODECONFIGS.
%
%   TXS and RXS are a NumFreq-by-NumNodes array containing the transmitter
%   and receiver sites for each unique frequency in the network. NumFreq is
%   the number of unique frequencies.

%   Copyright 2020-2021 The MathWorks, Inc.

% Initialize
numNodes = numel(nodeConfigs);

% Update the frequencies from the band and channel numbers
for nodeIdx = 1:numNodes
    config = nodeConfigs(nodeIdx);
    
    % Number of interfaces in the node
    numInterfaces = numel(config.BandAndChannel);
    for idx = 1:numInterfaces
        config.Frequency(idx) = ...
            hChannelToFrequency(config.BandAndChannel{idx}(2), config.BandAndChannel{idx}(1));
    end
    nodeConfigs(nodeIdx).Frequency = config.Frequency;
end

% Get node locattions (Assume same unit as triangulation unit)
nodeLocations = reshape([nodeConfigs.NodePosition],3,numNodes);

nodeFreqs = [nodeConfigs.Frequency];
uniqueFreqs = unique(nodeFreqs);
txs = repmat(txsite,numel(uniqueFreqs),numNodes);
nodeNames = arrayfun(@(x)strcat(" Node",num2str(x)),1:numNodes);
% Although we dont need a receiver site per frequency this allows other
% large scale parameters to be changed per interface as required.
rxs = repmat(rxsite,numel(uniqueFreqs),numNodes);
for i = 1:numel(uniqueFreqs)
    txs(i,:) = txsite("cartesian","Name",nodeNames,"AntennaPosition",nodeLocations,"TransmitterFrequency",uniqueFreqs(i)*1e9); % Frequencies are in GHz so convert to Hz
    rxs(i,:) = rxsite("cartesian","Name",nodeNames,"AntennaPosition",nodeLocations);
end

end