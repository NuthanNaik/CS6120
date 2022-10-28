function hVisualizeScenario(mapFileName,varargin)
%HVISUALIZESCENARIO Visualize 3-D map and tx/rx sites
%   hVisualizeScenario(MAPFILENAME) visualizes the 3-D map in the STL
%   file, MAPFILENAME.
%
%   hVisualizeScenario(MAPFILENAME, TXS) visualizes the 3-D map in the
%   STL file, MAPFILENAME, and transmitter sites, TXS. TXS is an array of
%   txsite objects or a 3-by-N matrix of Cartesian coordinates (in meters)
%   for N transmitters in the format [x;y;z]. The names of transmitter
%   sites are displayed if txsite objects are provided.
%
%   hVisualizeScenario(MAPFILENAME, TXS, RXS, APPOSITIONS) visualizes the
%   3-D map in the STL file, MAPFILENAME, transmitter sites, TXS, in red,
%   and receiver site, RXS, in blue. RXS is an array of rxsite objects, or
%   a 3-by-N matrix of Cartesian coordinates (in meters) for N receivers in
%   the format [x;y;z]. APPOSITIONS is an N-by-3 array specifying the
%   positions of APs, where N is the total number of rooms. The names of
%   receiver sites are displayed if rxsite objects are provided.
%
%   hVisualizeScenario(MAPFILENAME, TXS, NAMES) displays a text
%   annotation for transmitter sites. NAMES is a 1-by-N string array were
%   each element is the text annotation for a transmitter site.
%
%   hVisualizeScenario(..., "DisableNames",true) plots site locations
%   without displaying names. If not specified names are plotted.

%   Copyright 2021 The MathWorks, Inc. 

% Visualize the 3D map
if ~isa(mapFileName, 'triangulation')
    tri = stlread(mapFileName);
else
    tri = mapFileName;
end

% Visualize the 3D map from STL file
figure("Position", [360 360 600 600]);
trisurf(tri, ...
    'FaceAlpha', 0.3, ...
    'FaceColor', [.5, .5, .5], ...
    'EdgeColor', 'none');
view(60, 30);
hold on; axis equal; grid off;
xlabel('x'); ylabel('y'); zlabel('z');

% Plot edges
fe = featureEdges(tri,pi/20);
numEdges = size(fe, 1);
pts = tri.Points;
a = pts(fe(:,1),:); 
b = pts(fe(:,2),:); 
fePts = cat(1, reshape(a, 1, numEdges, 3), ...
    reshape(b, 1, numEdges, 3), nan(1, numEdges, 3));
fePts = reshape(fePts, [], 3);
plot3(fePts(:, 1), fePts(:, 2), fePts(:, 3), 'k', 'LineWidth', .5); 

if nargin>1
    % Disable name display with NV pair
    isDisableNamesControl = cellfun(@(x)(ischar(x)||isstring(x))&&strcmp(x,'DisableNames'),varargin);
    if any(isDisableNamesControl)
        disableNameArg = find(isDisableNamesControl)+1;
        if numel(varargin)<disableNameArg
            error('Expected name-value pair')
        end
        disableNames = varargin{disableNameArg};
    else
        disableNames = false;
    end
   
    % Visualize transmitter sites
    if isa(varargin{1},'txsite')
        txs = varargin{1};
        apPositions = varargin{3};
        [~,isAP] = intersect([txs(1,:).AntennaPosition]',apPositions,'rows');
        txs = txs(:,isAP);
        txPos = [txs.AntennaPosition];
        % Show node names
        if ~disableNames
            for i = 1:size(txs,2)
                text(txs(1,i).AntennaPosition(1),txs(1,i).AntennaPosition(2),txs(1,i).AntennaPosition(3),txs(1,i).Name);
            end
        end
    else
        txPos = varargin{1};
    end
    APs = scatter3(txPos(1,:), txPos(2,:), txPos(3,:), 'sr', 'filled');
    
    if nargin>2 && ~isDisableNamesControl(2)
        if (iscell(varargin{2}) || ischar(varargin{2}) || isstring(varargin{2}))
            % Show node names
            nodeNames = string(varargin{2});
            for i = 1:size(txPos,2)
                text(txPos(1,i),txPos(2,i),txPos(3,i),nodeNames(i))
            end
        else
            % Visualize receiver sites
            if isa(varargin{2},'rxsite') || isa(varargin{2},'txsite')
                rxs = varargin{2};
                isSTA = setdiff(1:size(rxs,2),isAP);
                rxs = rxs(:,isSTA);
                rxPos = [rxs.AntennaPosition];
                % Show node names
                if ~disableNames
                    for i = 1:size(rxs,2)
                        text(rxs(1,i).AntennaPosition(1),rxs(1,i).AntennaPosition(2),rxs(1,i).AntennaPosition(3),rxs(1,i).Name);
                    end
                end
            else
                rxPos = varargin{2};
            end
            STAs = scatter3(rxPos(1,:), rxPos(2,:), rxPos(3,:), 'sb', 'filled');
            legend([APs STAs],"AP","STA","location","best",'AutoUpdate','off')
        end
    end
end
end