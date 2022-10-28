function [txPositions, rxPositions] = hDropNodes(scenario)
%hDropNodes Returns random node positions based on scenario
%
%   [TXPOSITIONS, RXPOSITIONS] = hDropNodes(SCENARIO) generates and returns
%   random positions to the transmitter and receiver nodes in the network.
%
%   TXPOSITIONS is an N-by-M array where N is the number of APs per room
%   and M is the number of floors. It holds the positions of the
%   transmitters (APs) in the scenario.
%
%   RXPOSITIONS is an N-by-M array where N is the number of STAs per room
%   and M is the number of floors. It holds the positions of the
%   receivers (STAs) in the scenario.
%
%   SCENARIO is a structure specifying the following parameters:
%       BuildingLayout  - Layout in the form of [x,y,z] specifying number 
%                         of rooms in x-direction, number of rooms in 
%                         y-direction, and number of floors
%       RoomSize        - Size of the room in the form [x,y,z] in meters
%       NumRxPerRoom    - Number of stations per room

%   Copyright 2021 The MathWorks, Inc.

    numTx = prod(scenario.BuildingLayout);
    numRx = scenario.NumRxPerRoom*numTx; % for now

    dx = (0:scenario.BuildingLayout(1)-1)*scenario.RoomSize(1);
    dy = (0:scenario.BuildingLayout(2)-1)*scenario.RoomSize(2);
    dz = (0:scenario.BuildingLayout(3)-1)*scenario.RoomSize(3);

    [x,y,z] = meshgrid(dx,dy,dz);

    x0 = scenario.RoomSize(1)*rand(numTx,1);
    y0 = scenario.RoomSize(2)*rand(numTx,1);
    z0 = 1.5; % note we don't adjust z height

    txPositions = [x(:) + x0,y(:) + y0,z(:) + z0];

    x = repmat(x(:),[scenario.NumRxPerRoom,1]); 
    y = repmat(y(:),[scenario.NumRxPerRoom,1]); 
    z = repmat(z(:),[scenario.NumRxPerRoom,1]);
    x1 = scenario.RoomSize(1)*rand(numRx,1);
    y1 = scenario.RoomSize(2)*rand(numRx,1);
    z1 = 1.5; % note we don't adjust z height
    rxPositions = [x(:) + x1,y(:) + y1,z(:) + z1];
end