clear
close all
clc

addpath('..\Core\')

%% Pt.1 : Loading ECG recording

remote_load = false;

if remote_load
    [val, Fs] = rdsamp('ptbdb/patient025/s0087lre');
    save('PathologicalECG','val','Fs')
else
    load('PathologicalECG','val','Fs')
end

leads = 10:12;
[y,fs,t,lead_names,RRinterval] = PreprocECG(val,Fs,leads);
omega_ref = (2*pi/fs)./RRinterval;
[N,n] = size(y);


%% Pt.1a : Plotting the signal
close all
clc

FName = 'Times New Roman';
FSize = 12;
xl = [10 20];
% xl = [1201 2200]/fs;
clr = lines(4);
delta = 8;

figure('Position',[100 100 900 400])
for i=1:n
    plot(t,y(:,i)+delta*(i-1),'LineWidth',1.5,'Color',clr(1,:))
    hold on
    text(xl(1)+0.01*diff(xl),delta*(i-1)-delta/4,lead_names{i},'FontName',FName,'FontSize',FSize)
end
xlim(xl)
grid on
set(gca,'YTickLabel',[])
set(gca,'FontName',FName,'FontSize',FSize)
xlabel('Time [s]')

set(gcf,'PaperPositionMode','auto')
print('Figures\ECGpathology','-dpng','-r300')

%% Pt.2 : Estimating the signal components with the diagonal SS method
close all
clc

% Initialization
M = 34;
Orders = (1:M);

Optimize = true;

if Optimize
    IniGuess.Variances = [5e-5 1e-10];
    IniGuess.TargetFrequency = 2*pi*1.07/fs;
    Niter = 100;
    [~,logMarginal,HyperPar,Initial] = MO_DSS_JointEKF_FreqRef_EM(y(1001:2000,:)',omega_ref(1001:2000),Orders,Niter,IniGuess);
    
    save('Optimized_HyperPar_Pat','HyperPar','Initial','IniGuess','logMarginal','Niter')
    
else
    load('Optimized_HyperPar_Pat','HyperPar','Initial','IniGuess','logMarginal','Niter')
end

[Modal,logMarginal] = MO_DSS_JointEKF_FreqRef(y',omega_ref,Orders,HyperPar,Initial);

% [Modal,logMarginal,HyperPar] = MO_DSS_JointEKF_EM(y',M,Niter,IniGuess);

%% Signal spectrogram
close all
clc

lead = 1;
xl = [10 20];

Nf = 1024;
g = gausswin(Nf,12);
[Syy,ff,tt] = spectrogram(y(:,lead),g,Nf-1,Nf,fs);
Syy = abs(Syy).^2 * ( var(g)/Nf );
t_idx = tt >= xl(1) & tt <= xl(2);

figure('Position',[100 100 900 320])
imagesc(tt(t_idx),ff,10*log10(Syy(:,t_idx)))
axis xy
grid on
ylim([0 60])
xlim(xl)
ylabel('Frequency [Hz]')
xlabel('Time [s]')
cbar = colorbar('Location','eastoutside');
cbar.Label.String = 'Spectrogram [dB]';
set(gca,'CLim',[-70 -5],'FontName',FName,'FontSize',FSize)

set(gcf,'PaperPositionMode','auto')
print('Figures\ECGpat_spectrogram','-dpng','-r300')

%% Pt.3 : Showing results
close all
clc

for lead = 1:3
    
    figure('Position',[100 100 900 800])
    plot3(zeros(1,N),t,y(:,lead),'LineWidth',1.5,'Color',clr(2,:))
    hold on
    for i=1:min(10,M)
        
        ind = (1:2) + 2*(i-1);
        psi = zeros(1,2*M);
        psi(ind) = HyperPar.Psi(lead,ind);
        
        plot3(i*ones(1,N),t,psi*Modal.ym,'Color',clr(1,:),'LineWidth',1.5)
        
    end
    ylim(xl)
    zlim([-4 8])
    view([60 50])
    grid on
    xlabel('Harmonic index')
    ylabel('Time [s]')
    zlabel('Normalized amplitude')
    set(gca,'FontName',FName,'FontSize',FSize+2)
    
    set(gcf,'PaperPositionMode','auto')
    print(['Figures\ECGpathological_Modes',lead_names{lead}],'-dpng','-r300')
    
end

%% Performance after EM optimization
close all
clc

yhat = HyperPar.Psi*Modal.ym;
err = y' - yhat;

figure
for i=1:3
    subplot(3,1,i)
    plot(t,y(:,i))
    hold on
    plot(t,yhat(i,:))
    xlim(xl)
end

%- Reconstruction error plot
figure('Position',[100 100 900 300])
bar(100*sum( err(:,1001:2000).^2, 2 )./sum(y(1001:2000,:).^2)')
set(gca,'XTickLabel',lead_names)
set(gca,'FontName',FName,'FontSize',FSize+2)
ylabel({'Reconstruction error';'RSS/SSS (%)'})

set(gcf,'PaperPositionMode','auto')
print('Figures\ECGpathological_ErrorPerf','-dpng','-r300')

%- Optimized covariances plot
figure('Position',[100 400 900 360])
subplot(121)
bar(diag(HyperPar.Q(1:2:2*M,1:2:2*M))*1e4)
xlabel('Harmonic index')
ylabel('State innov. variance $\times 10^{-4}$','Interpreter','latex')
set(gca,'FontName',FName,'FontSize',FSize+2)
grid on

subplot(122)
imagesc(HyperPar.R(1:n,1:n)*1e4)
axis square
cbar = colorbar('Location','northoutside');
% set(gca,'CLim',max(max(abs(HyperPar.R(1:n,1:n))))*[-1 1]*1e3)
set(gca,'XTickLabel',lead_names,'YTickLabel',lead_names,'XTick',1:n,'YTick',1:n)
set(gca,'FontName',FName,'FontSize',FSize+2)
cbar.Label.String = 'Measurement noise covariance $\times 10^{-4}$';
cbar.Label.Interpreter = 'latex';

set(gcf,'PaperPositionMode','auto')
print('Figures\ECGpathological_Covariances','-dpng','-r300')

%- Optimized mixing matrix plot
figure('Position',[1000 100 900 360])
imagesc(abs(HyperPar.Psi))
set(gca,'YTickLabel',lead_names,'YTick',1:n)
xlabel('Harmonic index')
set(gca,'FontName',FName,'FontSize',FSize+2)
% set(gca,'CLim',max(max(abs(HyperPar.Psi)))*[-1 1])
cbar = colorbar;
cbar.Label.String = 'Absolute amplitude';

set(gcf,'PaperPositionMode','auto')
print('Figures\ECGpathological_MixMatrix','-dpng','-r300')

%%
close all
clc

leads = [1 3];
M_max = min(M,4);
yl = [-1 1; -1 1; -1 1; -1 1];

figure('Position',[100 100 900 800])
for j=1:2
    
    subplot(M_max+1,2,j)
    plot(t,y(:,leads(j)),'Color',clr(1,:),'LineWidth',1.5)
    xlim(xl)
    set(gca,'XTickLabel',[])
    ylabel(lead_names{leads(j)})
    set(gca,'FontName',FName,'FontSize',FSize)
    grid on
    
    for i=1:M_max
        
        Psi = zeros(1,2*M);
        ind = (1:2)+2*(i-1);
        Psi(ind) = HyperPar.Psi(leads(j),ind);
        
        subplot(M_max+1,2,2*i-j+3)
        plot(t,Psi*Modal.ym,'Color',clr(1,:),'LineWidth',1.5)
        xlim(xl)
        ylim(yl(i,:))
        ylabel(['Comp. ',num2str(i)])
        if i<M_max
            set(gca,'XTickLabel',[])
        else
            xlabel('Time [s]')
        end
        set(gca,'FontName',FName,'FontSize',FSize)
        grid on
    end
end

% % set(gcf,'PaperPositionMode','auto')
% % print('Figures\ECGpathological_HarmonicComponents','-dpng','-r300')

%%
close all
clc

delta = 8;

figure('Position',[100 100 900 900])
plot(t,y(:,lead),'Color',clr(1,:),'LineWidth',1.5)   
text(xl(1)-0.01*diff(xl),0,lead_names{lead},...
    'FontName',FName,'FontSize',FSize,'HorizontalAlignment','right')

hold on
for m=1:min(10,M)
    plot(t,Modal.ym(2*m,:)+delta*m,'Color',clr(2,:),'LineWidth',1.5)   
%     plot(t,Modal.ym(2*m-1,:)+delta*m,'Color',clr(2,:),'LineWidth',1.5)   
    
    text(xl(1)-0.01*diff(xl),delta*m,['m = ',num2str(m)],...
        'FontName',FName,'FontSize',FSize,'HorizontalAlignment','right')
end

xlim(xl)
grid on
if m==M, xlabel('Time [s]'), end
set(gca,'YTickLabel','')
set(gca,'FontName',FName,'FontSize',FSize)
xlabel('Time [s]')

%%
close all
clc

xl = [10 20];
lead = 2;

psi = HyperPar.Psi(lead,ind);
psi = sqrt( psi(1:2:end).^2 + psi(2:2:end).^2 );
A = diag(psi)*Modal.Am;
Mmax = M;
t_idx = t>=xl(1) & t<=xl(2);

figure('Position',[100 100 900 720])
subplot(3,1,3)
plot(t,y(:,lead))
xlim(xl)
grid on
ylabel('Normalized amplitude')
xlabel('Time [s]')
set(gca,'FontName',FName,'FontSize',FSize)

subplot(3,1,1:2)
imagesc(t(t_idx),1:Mmax,A(1:Mmax,t_idx))
axis xy
cbar = colorbar('Location','northoutside');
cbar.Label.String = 'Relative Amplitude';
xlim(xl)
grid on
ylabel('Harmonic component index')
xlabel('Time [s]')
set(gca,'FontName',FName,'FontSize',FSize)

set(gcf,'PaperPositionMode','auto')
print('Figures\ECGpathological_HarmonicComponents','-dpng','-r300')
