
clc; clear; close all;

%% 1. 读取图像与环境初始化
% 提示：请确保目录下有测试图片 'test_digit.png' 
% 如果测试手写数字，建议背景为白色，数字为黑色
[file, path] = uigetfile({'*.png;*.jpg;*.jpeg', '图像文件 (*.png, *.jpg, *.jpeg)'}, '请选择待识别的数字图像');
if isequal(file, 0)
    disp('用户取消了选择');
    return;
end
img_original = imread(fullfile(path, file));

%% 2. 图像预处理
% 2.1 灰度化
if size(img_original, 3) == 3
    img_gray = rgb2gray(img_original);
else
    img_gray = img_original;
end

% 2.2 滤波降噪（中值滤波）
img_filtered = medfilt2(img_gray, [3, 3]);

% 2.3 二值化（Otsu最大类间方差法）
% 确保数字为白色（1），背景为黑色（0）。如果是白底黑字，则进行反色
level = graythresh(img_filtered);
img_bin = imbinarize(img_filtered, level);

% 自动检查背景。如果四周边缘白色像素多，说明是白底黑字，需要反色
edge_pixels = [img_bin(1,:), img_bin(end,:), img_bin(:,1)', img_bin(:,end)'];
if mean(edge_pixels) > 0.5
    img_bin = ~img_bin;
end

% 2.4 形态学处理（闭运算连接断开的线条，开运算去噪）
se = strel('disk', 2);
img_morph = imclose(img_bin, se);
img_morph = imopen(img_morph, se);

%% 3. 单数字区域定位与分割
% 寻找连通域
stats = regionprops(img_morph, 'BoundingBox', 'Area');

if isempty(stats)
    error('未检测到有效的数字区域！');
end

% 筛选面积最大的连通域（防止杂质干扰）
[~, max_idx] = max([stats.Area]);
bbox = stats(max_idx).BoundingBox;

% 裁剪出数字区域并归一化为 32x32 尺寸（用于模板匹配）
img_crop = imcrop(img_morph, bbox);
img_normalized = imresize(img_crop, [32, 32]);

%% 4. 生成/载入数字模板 (0-9)
% 为了代码独立可运行，这里通过MATLAB自带系统字体动态生成标准 0-9 模板
templates = zeros(32, 32, 10);
for d = 0:9
    % 创建空白画布并写入数字
    temp_img = uint8(zeros(64, 64));
    temp_img = insertText(temp_img, [16, 8], num2str(d), 'FontSize', 40, 'BoxOpacity', 0, 'TextColor', 'white');
    temp_gray = rgb2gray(temp_img);
    temp_bin = imbinarize(temp_gray, 0.1);
    
    % 裁剪模板的紧凑区域并归一化
    t_stats = regionprops(temp_bin, 'BoundingBox');
    if ~isempty(t_stats)
        temp_crop = imcrop(temp_bin, t_stats(1).BoundingBox);
        templates(:,:,d+1) = imresize(temp_crop, [32, 32]);
    else
        templates(:,:,d+1) = imresize(temp_bin, [32, 32]);
    end
end

%% 5. 模板匹配与识别
correlations = zeros(1, 10);
for d = 0:9
    % 计算待识别数字与模板之间的二维相关系数
    correlations(d+1) = corr2(img_normalized, templates(:,:,d+1));
end

% 找到相关系数最大的索引
[max_corr, recognized_digit_idx] = max(correlations);
recognized_digit = recognized_digit_idx - 1;

%% 6. 结果可视化展示
figure('Name', '单数字图像识别系统', 'NumberTitle', 'off', 'Position', [100, 100, 1000, 600]);

subplot(2, 3, 1); imshow(img_original); title('1. 原始输入图像');
subplot(2, 3, 2); imshow(img_gray); title('2. 灰度化处理');
subplot(2, 3, 3); imshow(img_bin); title('3. 自适应二值化');
subplot(2, 3, 4); imshow(img_morph); title('4. 形态学滤波');

% 在原图上框选出数字
subplot(2, 3, 5); imshow(img_original); hold on;
rectangle('Position', bbox, 'EdgeColor', 'r', 'LineWidth', 2);
title('5. 目标区域定位');

% 显示识别结果
subplot(2, 3, 6); 
imshow(img_normalized);
title(sprintf('6. 识别结果: \\fontsize{20}\\color{red}%d\n\\fontsize{10}\\color{black}置信度: %.2f', recognized_digit, max_corr));

fprintf('系统识别完成！该图片中的数字为: %d (置信度: %.4f)\n', recognized_digit, max_corr);
