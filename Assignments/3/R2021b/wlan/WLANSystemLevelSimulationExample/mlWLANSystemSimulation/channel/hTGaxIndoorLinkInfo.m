function [numFloors, numWalls, dist] = hTGaxIndoorLinkInfo(TRI,txs,rxs,varargin)
%hTGaxIndoorLinkInfo Returns the number of floors, walls, and distance between points for a link
%   [NUMFLOORS,NUMWALLS,DIST] = hTGaxIndoorLinkInfo(TRI,TXS,RXS) returns the
%   number of floors, walls, and distance between points for a link.

%   Copyright 2021 The MathWorks, Inc.

% Suppress warnings we may expect during waveform analysis
% and restore state on function clean-up.
warningsToSuppress = ["MATLAB:triangulation:PtsNotInTriWarnId" ...
    "shared_raytracer:RayTracer:invalidFacetRT"];
warningState = arrayfun(@(x)warning('off',x),warningsToSuppress);
restoreWarningState = @()arrayfun(@(x)warning(x),warningState);
warn = onCleanup(restoreWarningState);

% Parse input parameters
p = inputParser;
addParameter(p,'FacesPerWall',2); % Assume two facets per wall/floor
addParameter(p,'WallZThreshold',0.1); % Threshold in m over which a triangle height difference is classed as a wall
addParameter(p,'FloorThicknessThreshold',0.6); % Threshold in m over which two facets are not classed as part of the same floor
addOptional(p,'UnitScalar',1);    % Assume units are meters
addOptional(p,'ShowPlot',false);

parse(p,varargin{:});
facesPerWall = p.Results.FacesPerWall;
unitScalar = p.Results.UnitScalar;
plotIntersect = p.Results.ShowPlot;
zThreshold = p.Results.WallZThreshold;
floorThicknessThreshold = p.Results.FloorThicknessThreshold;

% Normalize to the units as specified in meters
zThreshold = zThreshold/unitScalar;
floorThicknessThreshold = floorThicknessThreshold/unitScalar;

% Calculate number of floors, walls, and distance for each tx-rx link
% using ray tracing
RT = matlabshared.internal.StaticSceneRayTracer(TRI);
txPos = [txs.AntennaPosition];
rxPos = [rxs.AntennaPosition];

numFloors = zeros(numel(txs),numel(rxs));
numWalls = numFloors;
dist = numFloors;
for txIdx = 1:numel(txs)
    % Find any receivers in the same location as the transmitter and filter
    % them out
    issame = all(txPos(:,txIdx)'==rxPos',2);
    rxPosFilt = rxPos(:,~issame);
    rxFilt = rxs(~issame);

    if isempty(rxFilt)
        % If only one receiver and same as the transmitter then return
        % zeros
        numWalls(txIdx,:) = 0; 
        numFloors(txIdx,:) = 0; 
        continue
    end

    % Get the intersect points and intersected facets
    intPoints = cell(numel(rxs),1);
    intFaceIdx = cell(numel(rxs),1);
    [dir,distr] = matlabshared.internal.segmentToRay(txPos(:,txIdx)',  rxPosFilt');
    [intPoints(~issame),intFaceIdx(~issame)] = allIntersections(RT, txPos(:,txIdx)', dir, [zeros(numel(rxFilt),1) distr]);
    dist(txIdx,~issame) = distr;

    for rxIdx = 1:numel(rxs)
        if rxIdx == find(issame)
            % If rx is the same as the transmitter then 0
            numWalls(txIdx,rxIdx) = 0; 
            numFloors(txIdx,rxIdx) = 0; 
            continue
        end

        intLink = intFaceIdx{rxIdx};
        intPointRx = intPoints{rxIdx};

        % Get the connectivity and points for the link
        linkConnect = TRI.ConnectivityList(intLink,:); 
        linkPoints = TRI.Points(linkConnect.',:);

        % Get the z location for each triangle (each column). If the
        % difference in height within a triangle is below the threshold
        % then assume the triangle is a floor. Others are walls.
        z = reshape(linkPoints(:,3),3,[]);
        % These are vectors of possible surfaces which are a wall or floor
        isFloor = all(abs(diff(z))<zThreshold);
        isWall = ~isFloor;

        if any(plotIntersect)
            plotSurfaces(plotIntersect,TRI,linkConnect,intLink,isFloor,isWall,txs,rxs)
        end

        if facesPerWall==1
            % 1 facet per wall/floor
            
            % Find unique intersect points for wall facets
            [upointval,~,ipointb] = uniquetol(intPointRx(isWall,:),'ByRows',true);

            % If two or more facets share the same intersect point then
            % check if the face normals are the same. If they are then
            % there the intersection is on facets which make up the
            % same wall, otherwise they are different walls
            sharePoint = (1:size(upointval,1))==ipointb;
            numWallsTmp = size(upointval,1);
            numSame = sum(sharePoint);
            for up = 1:numel(numSame)
                if numSame(up)>1
                    intLinkTmp = intLink(isWall);
                    fn = faceNormal(TRI,intLinkTmp(sharePoint(:,up)));
                    % If face normals are unique then count as another
                    % wall if they share the same intersect point
                    numWallsTmp = numWallsTmp + size(uniquetol(fn,'ByRows',true),1)-1;
                end    
            end
            numWalls(txIdx,rxIdx) = numWallsTmp;

            % For floors the facets will always have the same face
            % normal so only count unique ones as no risk of two
            % intersect points for perpendicular faces
            numFloors(txIdx,rxIdx) = size(uniquetol(intPointRx(isFloor,:),'ByRows',true),1);
            continue
        end

        if sum(isFloor)>1  
            % Vector between intersect points of adjacent floors (in order
            % of intersect)
            intPointRxFloor = intPointRx(isFloor,:);
            % Order by z intersect
            intPointRxFloor = sortrows(intPointRxFloor,3);
            % Get the diff in intersect in z
            vp = diff(intPointRxFloor,1);

            % If thickness between diffs is greater than expected floor
            % height then assume they are different floors
            isSingleFloor = vp(:,3)>floorThicknessThreshold;
            numFloors(txIdx,rxIdx) = sum(isSingleFloor)+1;
        else
            numFloors(txIdx,rxIdx) = sum(isFloor);
        end

        % Assume that 2 elements for every wall/ceiling. Floor in case the
        % link cuts through an angle.
        numWalls(txIdx,rxIdx) = floor(sum(isWall)/2);
    end
end

end

function plotSurfaces(plotIntersect,TRI,intConnect,intLink,isFloor,isWall,txs,rxs)
    % Plot link and facets intersected

    assert(numel(txs)==1 && numel(rxs)==1,'Can only plot link info for 1 transmitter and receiver')

    plotBuildingWireframe(TRI);
    hold on;
    
    % Visualize sites
    txPos = [txs.AntennaPosition];
    rxPos = [rxs.AntennaPosition];
    scatter3(txPos(1,:), txPos(2,:), txPos(3,:), 'sr', 'filled');
    scatter3(rxPos(1,:), rxPos(2,:), rxPos(3,:), 'sb', 'filled');

    plotLink(txs,rxs);
    
    
    if (isscalar(plotIntersect) || plotIntersect(2)) && any(isFloor)
        % Plot floor surfaces
        cmap = colormap('lines');
        con = intConnect(isFloor,:);
        for i = 1:size(con,1)
            tFloor = triangulation(con(i,:),TRI.Points);
            trisurf(tFloor, ...
                'FaceAlpha', 0.3, ...
                'FaceColor', cmap(i,:), ...
               'EdgeColor', 'none');
        end
        P = incenter(TRI,intLink(isFloor));
        F = faceNormal(TRI,intLink(isFloor));
        quiver3(P(:,1),P(:,2),P(:,3), ...
             F(:,1),F(:,2),F(:,3),0.5,'color','r');
    end
    if (isscalar(plotIntersect) || plotIntersect(1)) && any(isWall)
        % Plot wall surfaces
        cmap = colormap('lines');
        con = intConnect(isWall,:);
        for i = 1:size(con,1)
            tWall = triangulation(con(i,:),TRI.Points);
            trisurf(tWall, ...
                'FaceAlpha', 0.3, ...
                'FaceColor', cmap(i,:), ...
               'EdgeColor', 'none');
        end
        P = incenter(TRI,intLink(isWall));
        F = faceNormal(TRI,intLink(isWall));
        quiver3(P(:,1),P(:,2),P(:,3), ...
             F(:,1),F(:,2),F(:,3),0.5,'color','g');
    end
end