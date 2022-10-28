function [pl,pathlossFn] = hCreatePathlossTable(txs,rxs,propModel)
%hCreatePathlossTable Create path loss table from transmitter and receiver sites
%   [PL,PATHLOSSFN] = hCreatePathlossTable(TXS,RXS,PROPMODEL) returns a
%   table of pathloss between all transmitter and receiver sites given a
%   propagation model.
%
%   TXS and RXS are txsite and rxsite objects and must be
%   NumFreq-by-NumNodes arrays.
%
%   PROPMODEL is rfprop.PropagationModel object.
%
%   PL is a numNodes-by-numNodes-by-NumFreq array containing the pathloss
%   in dB between each transmitter and receiver. Each row is the pathloss
%   from a given transmitter. The pathloss assumes channels are reciprocal.
%
%   PATHLOSSFN is an anonymous function handle to use the pathloss table:
%      PL = PATHLOSSFN(txIdx,rxIdx,freq)
%        txIdx is the transmitter node identifier
%        rxIdx is the receiver node identifier
%        freq is the carrier frequency in GHz

%   Copyright 2021 The MathWorks, Inc.

[numFreqs,numNodes] = size(txs);
assert(isequal(size(txs),size(rxs)))

% Use first column to get frequencies used
uniqueFreqs = [txs(:,1).TransmitterFrequency];

% Rows are transmitters, columns are receivers
pl = zeros(numNodes,numNodes,numFreqs);
for i = 1:numFreqs
    plf = pathloss(propModel,rxs(i,:),txs(i,:));
    % Make pathloss for links reciprocal - shadow fading may cause them not
    % to be when generated with pathloss
    pl(:,:,i) = triu(plf) + triu(plf,1)';
end

% Handle to lookup table anonymous function
pathlossFn = @(txIdx,rxIdx,freq) pl(txIdx,rxIdx,freq==uniqueFreqs/1e9);

end