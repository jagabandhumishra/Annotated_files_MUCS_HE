clc;
clear all;
close all;
addpath(genpath('/home/jagabandhu/data/JAGA-PHD/Research-work/SPK_chng_Lng_chng/Listening_test/req_base_programmes'))
%% 
%import test data
load('/home/jagabandhu/data/JAGA-PHD/Research-work/SPK_chng_Lng_chng/Model_exposure_v2/Full_data_anlys/train_test_data.mat')
path=test_data.path;
path=strrep(path,'/home/owner1/data/JAGA-PHD/Research-work/spk_Lang_chng_ana','/home/jagabandhu/data/JAGA-PHD/Research-work/spk_Lang_chng_ana');
splt_path=split(path,'/');
splt_filenm=splt_path(:,9);
fl_id=split(splt_filenm,'_');
fl_id=fl_id(:,2);
[un_fl,idx1,j]=unique(fl_id);
freq=accumarray(j,1);
un_fl=un_fl(freq>1);
cp=test_data.cp;
lab1=test_data.l1;
lab2=test_data.l2;
%% 

for i=1:length(un_fl)
   idx=find(strcmp(fl_id,un_fl{i}));
   fl_path=path(idx);
   cp1=cp(idx);
   lab11=lab1(idx);
   lab21=lab2(idx);
   
   
   dd=[];
   dur=zeros(2*length(fl_path),2);
   
   ll=1;
   for jj=1:length(fl_path)
     [d,fs]=audioread(fl_path{jj});
     ln(jj)=length(d);
     cpp=cp1{jj};
     dur(ll,1)=numel(dd)+1;
     lang(ll)=cell2mat(lab11(jj));
     dur(ll,2)=numel(dd)+cpp;ll=ll+1;
     dur(ll,1)=numel(dd)+cpp+1;
     dd=[dd;d];
     lang(ll)=cell2mat(lab21(jj));
     dur(ll,2)=length(dd);ll=ll+1;
     
     
   end
   gr_tr{i}=table(dur,lang'); 
   d=(dd-mean(dd))./(1.01*max(abs(dd)));
   data{i}=d;
   
   %% VAD and lang mask
audioIn=data{i};
mergeDuration = 0.125; % atleast 0.5 seconds of voiced frame
VADidx = detectSpeech(audioIn,fs,'MergeDistance',fs*mergeDuration);
%VADidx = detectSpeech(audioIn,fs);
VADmask{i} = sigroi2binmask(VADidx,numel(audioIn));

%plot(audioIn);hold on; plot(langmask);hold off
langmsk{i}=signalMask(table(gr_tr{i}.dur,categorical(cellstr(gr_tr{i}.Var2))));
   
end

%% VAD segmentation 


%plotsigroi(langmsk{12},data{12});hold on;plot(VADmask{12},'k')
%% feature extraction (lets 1st do it for one file)
block_size=(20*fs)/1000;
shift=block_size/2;

aIn=data{1};
% % computes the location  of voiced frames
% [~,~,loc,~]=ener_frames(aIn,block_size,shift);
% 
% frloc=(((loc-1)*shift)+((loc-1)*shift)+block_size)./2; %% mid frame location of the voiced frame

[MFCC DMFCC DDMFCC]=mfcc_delta_deltadelta_rasta_v5_no_vad(aIn,fs,14,24,20,10,1,1,2); 
    
%mfcc=[MFCC(loc,2:end), DMFCC(loc,2:end), DDMFCC(loc,2:end)];
mfcc=[MFCC(:,2:end), DMFCC(:,2:end), DDMFCC(:,2:end)];
%% load the GMM model
load('/home/jagabandhu/data/JAGA-PHD/Research-work/SPK_chng_Lng_chng/Model_exposure_v2/Full_data_anlys/ubm_full_data_train.mat')
%% compute Ni for each 50 frames

context=100;
shift=1;

for j=1:size(mfcc,1)-context
st=(j-1)*shift+1;
en=(j-1)*shift+context;

Ni{j}=compute_ni_gmm(mfcc(st:en,:),adpt_eng);
Nj{j}=compute_ni_gmm(mfcc(st:en,:),adpt_hnd);

end
Ni=[Ni{:}];
Nj=[Nj{:}];
N=[Ni;Nj];
%% clustering
maxclusters=2; % as we have only 2 language
[T,Z] = clusterdata(N','Criterion','distance','distance','euclid','linkage','average','maxclust',maxclusters);
%% lets see the likelihood contour once
llk_ubm=gmmlpdf_voicebox_pkm_v1(mfcc,ubm.m,ubm.v,ubm.w);
  
llk_ubm_eng=gmmlpdf_voicebox_pkm_v1(mfcc,adpt_eng.m,ubm.v,ubm.w);
llk_ubm_hnd=gmmlpdf_voicebox_pkm_v1(mfcc,adpt_hnd.m,ubm.v,ubm.w);
  
  
 %% evidence contour
 
evd_cntr_ubm=[llk_ubm_hnd'-llk_ubm';llk_ubm_eng'-llk_ubm']';

[T1,Z1] = clusterdata(evd_cntr_ubm,'Criterion','distance','distance','minkowski','linkage','average','maxclust',maxclusters);
plot(T1)