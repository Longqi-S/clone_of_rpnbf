function rects = pseudoNMS(candi_rects)

% overlapping threshold for grouping nearby detections
overlappingThreshold = 0.5; 

% candi_rects: N x 5 matrix, each row: [x1 y1 x2 y2 score]
if isempty(candi_rects)
    rects = [];
    return;
end

area_all = (candi_rects(:,3) - candi_rects(:,1) + 1) .* (candi_rects(:,4) - candi_rects(:,2) + 1);

numCandidates = size(candi_rects, 1);
predicate = eye(numCandidates); % i and j belong to the same group if predicate(i,j) = 1

% mark nearby detections
for i = 1 : numCandidates
    for j = i + 1 : numCandidates
        h = min(candi_rects(i,4), candi_rects(j,4)) - max(candi_rects(i,2), candi_rects(j,2)) + 1;
        w = min(candi_rects(i,3), candi_rects(j,3)) - max(candi_rects(i,1), candi_rects(j,1)) + 1;
        if h <= 0 || w <= 0
           continue; 
        end
        s = max(h,0) * max(w,0);  
        if s / (area_all(i) + area_all(j) - s) >= overlappingThreshold
            predicate(i,j) = 1;
            predicate(j,i) = 1;
        end
    end
end

% merge nearby detections
[label, numCandidates] = Partition(predicate);

%rects = struct('row', zeros(numCandidates,1), 'col', zeros(numCandidates,1), ...
%    'size', zeros(numCandidates,1), 'score', zeros(numCandidates,1), ...
%    'neighbors', zeros(numCandidates,1));
rects = zeros(numCandidates, 5);

for i = 1 : numCandidates
    index = find(label == i);
    %weight = Logistic([candi_rects(index).score]');
    % now a row vector
    weight = candi_rects(index, 5)';
    rects(i,5) = max( weight );  %1006: sum --> max
    %rects(i).neighbors = length(index);
    
    %normalize weight
    weight = weight / sum(weight);
    
    ave_center_x = weight * (candi_rects(index, 1) + candi_rects(index, 3))/2;
    ave_center_y = weight * (candi_rects(index, 2) + candi_rects(index, 4))/2;
    ave_w = weight * (candi_rects(index, 3) - candi_rects(index, 1));
    ave_h = weight * (candi_rects(index, 4) - candi_rects(index, 2));
    rects(i,1) = round(ave_center_x - ave_w/2);
    rects(i,2) = round(ave_center_y - ave_h/2);
    rects(i,3) = round(ave_center_x + ave_w/2);
    rects(i,4) = round(ave_center_y + ave_h/2);
    %rects(i).size = floor([candi_rects(index).size] * weight);
    %rects(i).col = floor(([candi_rects(index).col] + [candi_rects(index).size]/2) * weight - rects(i).size/2);
    %rects(i).row = floor(([candi_rects(index).row] + [candi_rects(index).size]/2) * weight - rects(i).size/2);
end

clear candi_rects;

% find embeded rectangles
predicate = false(numCandidates); % rect j contains rect i if predicate(i,j) = 1
area_rect = (rects(:,3) - rects(:,1) + 1) .* (rects(:,4) - rects(:,2) + 1);
for i = 1 : numCandidates
    for j = i + 1 : numCandidates
        %h = min(rects(i).row + rects(i).size, rects(j).row + rects(j).size) - max(rects(i).row, rects(j).row);
        %w = min(rects(i).col + rects(i).size, rects(j).col + rects(j).size) - max(rects(i).col, rects(j).col);
        h = min(rects(i,4), rects(j,4)) - max(rects(i,2), rects(j,2)) + 1;
        w = min(rects(i,3), rects(j,3)) - max(rects(i,1), rects(j,1)) + 1;
        if h <= 0 || w <= 0
           continue; 
        end
        s = max(h,0) * max(w,0);

        if s / area_rect(i) >= overlappingThreshold || s / area_rect(j) >= overlappingThreshold
            predicate(i,j) = true;
            predicate(j,i) = true;
        end
    end
end

flag = true(numCandidates,1);

% merge embeded rectangles
for i = 1 : numCandidates
    index = find(predicate(:,i));

    if isempty(index)
        continue;
    end

    %s = max([rects(index).score]);
    s = max(rects(index,5));
    %if s > rects(i).score
    if s > rects(i,5)
        flag(i) = false;
    end
end

%rects = rects(flag);
rects = rects(flag, :);

% check borders
% [height, width, ~] = size(I);
% numFaces = length(rects);
% 
% for i = 1 : numFaces
%     if rects(i).row < 1
%         rects(i).row = 1;
%     end
%     
%     if rects(i).col < 1
%         rects(i).col = 1;
%     end
%     
%     rects(i).height = rects(i).size;
%     rects(i).width = rects(i).size;
%     
%     if rects(i).row + rects(i).height - 1 > height
%         rects(i).height = height - rects(i).row + 1;
%     end
%     
%     if rects(i).col + rects(i).width - 1 > width
%         rects(i).width = width - rects(i).col + 1;
%     end    
% end
end