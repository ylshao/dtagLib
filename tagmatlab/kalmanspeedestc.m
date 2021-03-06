function      [s,fit,a] = kalmanspeedestc(p,Aw,fs,th)
%
%     [s,fit] = kalmanspeedestc(p,Aw,fs,th)
%     EXPERIMENTAL !!
%     Estimate the swim speed of a whale with given depth profile, p, in m, and
%     accelerometer vector Aw, sampled at rate fs, Hz. th is a censoring threshold
%     in g. Process is a 2-state Kalman
%     filter estimating speed and depth, followed by a Rauch smoother.
%     Acceleration values abs(1-norm2(Aw)) greater than th are replaced with interpolated
%     values using a cubic spline. For these samples, the state noise matrix is also
%     multiplied by 100 to indicate the transition matrix of lower quality.
%     
%     Output:
%     s  is the swim speed estimate in m/s
%     fit is a structure of results including:
%      fit.ks = kalman filtered speed
%      fit.kd = kalman depth estimate
%      fit.rd = rauch depth estimate
%      fit.kp = kalman a posteriori state covariance (2x2xn)
%
%     mark johnson, WHOI
%     majohnson@whoi.edu
%     October 2007

if nargin<4
   help kalmanspeedestc
   return
end

r = 0.001 ;          % measurement noise cov. - this should be set equal to the noise power
                     % in the depth estimate, p, e.g., 0.05 m^2. was 0.005
q1 = (0.02/fs)^2 ;   % speed state noise cov. - accounts for variations in speed, was 0.05
q2 = (0.08/fs)^2 ;   % depth state noise cov. - accounts for errors in pitch
T = 1/fs ;           % sampling period

% remove suspect acceleration measurements
n = norm2(Aw) ;
g = abs(n-1) ;          % 'excess' acceleration 
a = -Aw(:,1)./n*T ;     % scaled x axis acceleration, transition matrix entry (2,1)
kb = find(g>=th) ;
kg = find(g<th) ;
a(kb) = interp1(kg,a(kg),kb,'cubic') ;
m = ones(length(p),1) ;
m(kb) = 1 ;           % increase state noise when acceleration is unreliable
                        % how to justify this?

% vector Kalman filter with 2 states: s and p

shatm = [1;p(1)] ;      % starting state estimate
H = [0 1] ;             % observation vector
Pm = [0.01 0;0 r] ;     % initial state covariance matrix:
                        % says how much we trust initial values of s and p?
%Q = [q1 0;0 q2]         % make state noise matrix
%Q = [T T^2;T^2 T^2/2]*1e-4

skal = zeros(2,length(p)) ;    % place to store states
srau = skal ;
Ps = zeros(2,2,length(p)) ;
Pms = Ps ;

q2base = a*T/2 ;
q3base = a.^2*T/3 ;

for k=1:length(p),             % Kalman filter
   Ak = [1 0;a(k) 1] ;         % make state transition matrix

%q2k = q2base(k)+T/10*shatm(1) ;
%q3k = q3base(k)+q2base(k)/5*shatm(1)+shatm(1)^2*T/100 ;
Qk = [T q2base(k);q2base(k) q3base(k)]*1e-4 ;  
%Qk = Q ;

   if k>1,
      Pm = Ak*P*Ak' + m(k)*Qk ;    % update a priori state cov
      shatm = Ak*shat ;        % a priori state estimate
   end

   K = Pm*H'/(H*Pm*H'+r) ;    % compute kalman gain
   shat = shatm + K*(p(k)-H*shatm) ;  % a posteriori state estimate
   P = (eye(2)-K*H)*Pm ;      % a posteriori state cov

   skal(:,k) = shat ;         % store results of iteration
   Pms(:,:,k) = Pm ;
   Ps(:,:,k) = P ;
end

%Vh is P(T)
srau(:,length(p)) = shat ;

for k=length(p):-1:2,                % Kalman/Rauch smoother
   Ak = [1 0;a(k-1) 1] ;                  % make state transition matrix
   K = Ps(:,:,k-1)*Ak'*inv(Pms(:,:,k));   % smoother gain
   srau(:,k-1) = skal(:,k-1)+K*(srau(:,k)-Ak*skal(:,k-1)) ; % smooth state
end

s = srau(1,:)' ;
if nargout>=2,
   fit.ks = skal(1,:)' ;
   fit.kd = skal(2,:)' ;
   fit.rd = srau(2,:)' ;
   fit.kp = Ps ;
end
