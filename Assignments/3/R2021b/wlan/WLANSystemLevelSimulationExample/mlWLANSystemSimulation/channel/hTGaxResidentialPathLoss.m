classdef hTGaxResidentialPathLoss < rfprop.PropagationModel
%hTGaxResidentialPathLoss Propagation model for WLAN TGax Residential scenario.
%   PM = hTGaxResidentialPathLoss creates a propagation model of type
%   TGaxResidential
%
%   PM = hTGaxResidentialPathLoss(Name, Value, ...) creates a propagation
%   model for TGaxResidential scenario, with additional properties
%   specified by one or more name-value pair arguments. Properties you do
%   not specify retain their default values.
%
%   hTGaxResidentialPathLoss properties:
%
%      Triangulation - Triangulation object representing building geometry
%      TriangulationUnit - Number of meters per triangulation point unit
%      FacesPerWall - Expected number of faces per wall
%      ShadowSigma - Large-scale shadow fading standard deviation in dB
%      WallZThreshold - Threshold over which a triangle height difference is classed as a wall
%      FloorThicknessThreshold - Maximum expected floor thickness
%
%   hTGaxResidentialPathLoss methods:
%
%      pathloss - Path loss of radio wave propagation
%      linkInfo - Link penetration details
%      visualizeLinkInfo - Visualize penetration details

%   Copyright 2021 The MathWorks, Inc.  
        
    properties
        %Triangulation Triangulation object representing building geometry
        %   Specify the building geometry as a triangulation object.
        %   The number of meters per point "unit" must be specified using
        %   the TriangulationUnit property.
        %   The expected number of faces per wall/floor must be specified
        %   using the FacesPerWall property.
        %   The model assumes there are no wall triangles within the space
        %   between floors.
        Triangulation;

        %TriangulationUnit Number of meters per triangulation point unit
        %   Specify the number of meters represented by a triangulation
        %   point unit. The default is 1.
        TriangulationUnit (1,1) double {mustBeFinite, mustBeReal, mustBeNonnegative, mustBeNonzero, mustBeNonsparse} = 1;

        %FacesPerWall Expected number of facets per wall
        %   Specify the expected number of triangulation facets
        %   representing a wall or floor. The default is 2.
        FacesPerWall (1,1) double {mustBeFinite, mustBeReal, mustBeNonnegative, mustBeNonzero, mustBeNonsparse} = 2;
        
        %ShadowSigma Large-scale shadow fading standard deviation id dB
        %   Specify the large-scale shadow fading standard deviation in dB.
        %   The default is 5 dB.
        ShadowSigma (1,1) double {mustBeFinite, mustBeReal, mustBeNonnegative, mustBeNonsparse} = 5;
        
        %WallZThreshold Threshold over which a triangle height difference is classed as a wall
        %   Specify the threshold in meters over which a triangle height
        %   difference is classed as a wall. The default is 0.1 meters.
        WallZThreshold (1,1) double {mustBeFinite, mustBeReal, mustBeNonnegative, mustBeNonzero, mustBeNonsparse} = 0.1;
        
        %FloorThicknessThreshold Maximum expected floor thickness
        %   Specify the threshold in meters which two facets are not
        %   classed as part of the same floor. The default is 0.6 meters.
        FloorThicknessThreshold (1,1) double {mustBeFinite, mustBeReal, mustBeNonnegative, mustBeNonzero, mustBeNonsparse} = 0.6;
    end
    
    methods      
      function [numFloors,numWalls,distance] = linkInfo(plm,txs,rxs)
            %linkInfo     Link penetration details
            %   (NUMFLOORS,NUMWALLS,DISTANCE] = linkInfo(PLM,TX,RX) returns
            %   the derived penetration details for links. TX are txsite
            %   objects and RX are rxsite objects.
        
          % Determine number of floors and walls penetrated for each link
          [~,numFloors,numWalls,distance] = wlanresidentialpnl(plm,txs,rxs);
      end
      
      function visualizeLinkInfo(plm,tx,rx)
            %visualizeLinkInfo     Visualize penetration details
            %   visualizeLinkInfo(PLM,TX,RX) plots the facets used in the
            %   penetration calculation.
          visualize = true;
          hTGaxIndoorLinkInfo(plm.Triangulation, tx, rx, plm.TriangulationUnit, visualize, ...
              'FacesPerWall', plm.FacesPerWall, ...
              'WallZThreshold', plm.WallZThreshold, ...
              'FloorThicknessThreshold', plm.FloorThicknessThreshold);
      end
    end

    methods(Access = protected)
        function pl = pathlossOverDistance(pm, rxs, tx, d, ~)
            % Scale distance into meters
            d = d*pm.TriangulationUnit;
          
            % Path loss
            pl = wlanresidentialpl(pm,d,tx.TransmitterFrequency);

            % Penetration loss
            pnl = wlanresidentialpnl(pm,tx,rxs);
            
            % Large-scale shadow fading
            sf = pm.ShadowSigma*randn(size(pl));
            
            pl = pl + pnl + sf;
        end
    end
    
    methods (Access = protected)
        
        function L = wlanresidentialpl(~,R,freq)
            %wlanresidentialpl     wlanresidential path loss
            %   L = wlanresidential() returns the WLAN Residential scenario path loss  in dB.
            %
            %   Note that the best case is lossless, so the loss is always greater than
            %   or equal to 0 dB.
            
            R = max(R,1); % minimum distance is 1 meter
            L = 40.05+20*log10(freq/2.4e9) + 20*log10(min(R,5)) + 35*(R>5).*log10(R/5);
        end
        
        function [L,numFloors,numWalls,distance] = wlanresidentialpnl(plm,txs,rxs)
            %wlanresidentialpnl     wlanresidential penetration loss
            %   L = wlanresidentialpnl() returns the WLAN Residential scenario path loss  in dB.
            %
            %   Note that the best case is lossless, so the loss is always greater than
            %   or equal to 0 dB.

            % Determine number of floors and walls penetrated for each link
            [numFloors,numWalls,distance] = hTGaxIndoorLinkInfo(plm.Triangulation, txs, rxs, plm.TriangulationUnit, ...
              'FacesPerWall', plm.FacesPerWall, ...
              'WallZThreshold', plm.WallZThreshold, ...
              'FloorThicknessThreshold', plm.FloorThicknessThreshold);
                        
            % penetration loss
            L = 18.3*numFloors.^((numFloors+2)./(numFloors+1) -0.46) + 5*numWalls;
        end
        
    end
    
end

