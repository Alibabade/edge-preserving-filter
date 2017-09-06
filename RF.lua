
--[[

  This script is the torch implementation of the domain transform Recursive Filter 
  described in the paper:
  
    Domain Transform for Edge-Aware Image and Video Processing
    Eduardo S. L. Gastal and Manuel M. Oliveira
    ACM Transactions on Graphics. Volume 30 (2011), Number 4.
    Proceedings of SIGGRAPH 2011, Article 69.

--]]

--[[

  RF Domain tranform recursive edge-preserving fitler

  F = RF(img, sigma_s, sigma_r, num_iterations, joint_image)

  Parameters:
    img:             input image to be filtered
    sigma_s:         Filter spatial standard deviation
    sigma_r:         Filter range standard deviation
    num_iterations   Number of iterations to perform (defualt: 3)
    joint_image      Optional image for joint filtering.

--]]


require 'torch'
require 'math'
require 'image'

function main()

  local I = image.load('woman.png',3):double()
  local sigma_s = 100
  local sigma_r = 1.04
  local I_clone= I:clone()
  local F_rf = RF(I_clone, sigma_s,sigma_r):double()
 
  image.save('RF_result.png', F_rf)

end


function RF(img, sigma_s, sigma_r, num_iterations, joint_image)

  local I = img:double()
  
  if num_iterations == nil then
     num_iterations = 3
  end

  local J = nil;
  if joint_image ~= nil then
     J = joint_image:double()
     if I:size(2) ~= J:size(2) and I:size(3) ~= J:size(3) then
        error('Input and joint image must have equal width and height.')
     end
  else
     J = I
     
  end

  local h,w, num_joint_channels = J:size(2), J:size(3), J:size(1)
  
  -- compute the domain transform (Equation 11 fo our paper)

  --Estimate horizontal and vertical partial derivatives using finite differences.
  local dIcdx = diff(J,1,2)
  local dIcdy = diff(J,1,1)

  local dIdx = torch.zeros(h,w)
  local dIdy = torch.zeros(h,w)

  --Compute the l1-norm distance of neighbour pixels

  for c = 1, num_joint_channels do
      dIdx[{{},{2,-1}}] = dIdx[{{},{2,-1}}] + torch.abs( dIcdx[c] )
      dIdy[{{2,-1},{}}] = dIdy[{{2,-1},{}}] + torch.abs( dIcdy[c] )
  end

  --Compute the derivatives of the horizontal and vertical domain transforms.
  local dHdx = (1 + sigma_s/sigma_r * dIdx)
  local dVdy = (1 + sigma_s/sigma_r * dIdy)

  --The vertical pass is performed using a transposed image.
  local dVdy = dVdy:t()

  
  --Perform the filtering-------------------------------------
  local N = num_iterations
  local F = I
  
  local sigma_H = sigma_s
  
  for i = 0, num_iterations - 1 do 
     
      --Compute the sigma value for this interation (Equation 14 of our paper)
      local sigma_H_i = sigma_H * torch.sqrt(3) * 2^(N - (i + 1)) / torch.sqrt(4^N - 1)

      F = TransformedDomainRecursiveFilter_Horizontal(F, dHdx, sigma_H_i)
      F = image_transpose(F)
 
      F = TransformedDomainRecursiveFilter_Horizontal(F, dVdy, sigma_H_i)
      F = image_transpose(F)
  end

  F = F:double()
  return F
end



function TransformedDomainRecursiveFilter_Horizontal(I, D, sigma)

  --Feedback coefficient (Appendix of our paper)
  local a = torch.exp(-torch.sqrt(2) / sigma)
  --print(D)
  local F = I
  local V = torch.pow(a,D)
  ---print(V:size())

  local h,w, num_channels = I:size(2), I:size(3),I:size(1)

  --Left -> Right filter
  for c = 1, num_channels do
      local F_tmp = torch.Tensor(num_channels, w,h)
      F_tmp[c] = F[c]:t()
      for i = 2, w do
          F_tmp[c][i] = F_tmp[c][i] + torch.cmul(V[{{},{i}}] , ( F_tmp[c][i-1] - F_tmp[c][i] ) )
      end
      F[c] = F_tmp[c]:t()
  end

  --Right -> Left filter
  for c = 1, num_channels do
      local F_tmp = torch.Tensor(num_channels, w,h)
      F_tmp[c] = F[c]:t()
      for i = w-1, 1, -1 do
          F_tmp[c][i] = F_tmp[c][i] + torch.cmul(V[{{},{i+1}}] , ( F_tmp[c][i+1] - F_tmp[c][i] ) )
      end
      F[c] = F_tmp[c]:t()
  end
  return F
end

function image_transpose(I)

  local h,w,num_channels = I:size(2), I:size(3), I:size(1)

  local T = torch.zeros(num_channels,w,h):double()
  
  for c = 1, num_channels do
      T[c] = I[c]:t()
  end
  return T
end

function diff(x, n,m)

  local c,h,w = x:size(1),x:size(2),x:size(3)
  local r = nil
  if m == 2 then  --differences between colomns
    r = torch.Tensor(c, h, w-1)
    for i = 1, c do 
        local x_tmp= torch.Tensor(c,w,h)
        x_tmp[i] = x[i]:t()
        --r[i] = r[i]:t()
        tmp = torch.Tensor(w-1,h)
        for j = 1, w -1 do 
            
            tmp[j] = x_tmp[i][j+1] - x_tmp[i][j]          
             --problem
        end
        r[i] = tmp:t()
    end
  elseif m == 1 then  -- distance between rows
    r = torch.Tensor(c, h-1, w)
    for i = 1, c do 
        tmp = torch.Tensor(h-1,w)
        for j = 1, h -1 do
            tmp[j] = x[i][j+1] - x[i][j] 
        end
        r[i] = tmp
    end
  end
  return r
end

main()


