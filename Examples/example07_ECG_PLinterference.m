clear
close all
clc

addpath('..\Core\')

%% Pt.1 : Loading ECG recording

Fs = 1e3;
fs = 500;
load('Data\ECG PTB db\patient284\s0543_rem.mat','val')

y = resample(val',fs,Fs);
y = y(1:1e4,7:12);
y = detrend(y);
y = y/diag(std(y));
[N,n] = size(y);
t = (0:N-1)/fs;

figure
for i=1:6
    plot(t,8*i+y(:,i))
    hold on
end

%% Pt.2 : Estimating the signal components with the diagonal SS method
% close all
clc

% Initialization
M = 16;
Niter = 50;
T = 1:1.25e3;
Initial.Variances = [1 1e-4 1e-8];
Initial.Freqs = pi/4*(logspace(-1,0,M));

[~,~,HyperPar,Initial] = MO_DSS_JointEKF_EM(y(T,:)',M,Niter,Initial);
[Modal,logMarginal,State,Covariances,Gain] = MO_DSS_JointEKF(y',M,'KS',Initial,HyperPar);

%% Pt.3 : Showing results
% close all
clc

xl = [10 20];

clr = lines(3);
FName = 'Times New Roman';
FSize = 12;

figure('Position',[100 100 600 500])
for m=1:M
    subplot(M/2,2,m)
    plot(t,Modal.ym(2*m,:),'Color',clr(2,:),'LineWidth',1.5)
    xlim(xl)
    grid on
    if m==M, xlabel('Time [s]'), end
    ylabel(['Mode ',num2str(m)])
    set(gca,'FontName',FName,'FontSize',FSize)
    
end

figure('Position',[700 100 600 500])
plot(t,Modal.omega*fs/(2*pi),'Color',clr(1,:),'LineWidth',1.5)
% xlim(xl)
grid on
xlabel('Time [s]')
ylabel('IF [Hz]')
set(gca,'FontName',FName,'FontSize',FSize)

%%
% close all
clc

xl = [10 20];

figure
for i=1:n
    subplot(n/2,2,i)
    plot(sqrt( HyperPar.Psi(i,1:2:end).^2 + HyperPar.Psi(i,2:2:end).^2 ))
    ylim([0 inf])
end

figure
for i=1:n
    psi = HyperPar.Psi(i,:);
    psi(2*(m-1)+(1:2)) = 0;
    
    subplot(n,1,i)
    plot(t,y(:,i))
    hold on
    plot(t,psi*Modal.ym)
    xlim(xl)
end

%%
% close all
clc

xl = [12 14];
r = 2;

figure
for i=1:M
    
    ind = (1:2) + 2*(i-1);
    psi = zeros(1,2*M);
    psi(ind) = HyperPar.Psi(r,ind);
    
    subplot(M/2,2,i)
    plot(t,y(:,r))
    hold on
    plot(t,psi*Modal.ym)
    xlim(xl)
end

%%
% close all
clc

figure
subplot(131)
imagesc(sqrt(HyperPar.Psi(:,1:2:end).^2 + HyperPar.Psi(:,2:2:end).^2))

subplot(132)
semilogy(diag(HyperPar.Q))

subplot(133)
imagesc(HyperPar.R)
