rm(list=ls())
setwd("~/Documents/project/whiplash-bpm/")

# install and load packages packages
packages = c("audio","Rcpp","ggplot2","signal","MASS","splines")
new.packages <- packages[!(packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
lapply(packages, require, character.only=T)


source("fnc.R") # all the usefull R functions
sourceCpp("kalmanCpp.cpp")


signal <- load.wave("data/02-whiplash-final.wav")[1,] # audio signal
fs     <- 48000 # sampling rate

# High pass-filter because we want to detect abrupt change
# Also remove some noise
but     <- butter(4, 0.2, 'low')
s.filt  <- signal::filter(but,signal)[-(1:10)] # filter and remove 
N       <- length(s.filt)

# State Space
# we supposed that the the signal generated by a drum is an AR(1): s_t = a*s_{t-1} + b_t
# where a is the ar coefficient, and b_t ~ N(0, sigma^2_n) is a white noise 
# So the hypothesis test writes:
# H0 (absence of drum): x_t = b_t
# H1 (presence of drum) x_t = s_t b_t


# X(t) = F*X(t-1) + sigma_n*rho*v_t
# Y(t) = H*X(t) + sigma_n*w_t
# with w_t, v_t ~ N(0, 1)
# rho^2 = sigma_s^2/sigma_n^2, where sigma_s^2 is the variance of the innovation,
# and sigma_n^2 is the noise variance

Xt_t        <- 0 # initial state
F           <- -0.95 # ar coefficient
Q           <- 1
R           <- 1
H           <- 1
rho2        <- .5 # snr #.5
win.length  <- 2048  #2048 # length of the window used to estimate sigma^2_n #1024
slid.length <- 128  # overlap

# cusum (related to the likelihood ratio)
cusum <- kalmanCpp(Sig = s.filt, Q = Q,F = F, H = H, R = R, min_sigma2b = .00001,
                   rho2 = rho2, Qt_ = rep(0, N), winnoise = win.length, overlap=slid.length)[[1]]
cusum.log <- log(1+cusum)

X <- cbind(s.filt, cusum.log)
plot(as.ts(X[1:30000,]))


# nsamples.ignore: number of point after which we suppose that 
# it is impossible to have a second detection
# 1440 = 1/1500*fs*60. I suppose that he can't drum quicker that 2000bpm

#peaks <- findPeaks(x = cusum.log, threshold = 1.9, nsamples.ignore = 1/1500*fs*60, norm = TRUE)
peaks <- findPeaksCpp(X = cusum.log, threshold = 1.9, maxBPM = 1500, norm = TRUE,fs = fs)[[1]]

#col   <- findPeaks(x = cusum.log, threshold = 1.9, nsamples.ignore = 1920, norm = FALSE)


# Let compute the instantaneous bpm
# 1/(sec between detections)*60
bpm <- calc.bpm(peaks, fs)

(sum(peaks))

# PLOTSSSSS!
# col <- col[-which(col==0)]
#df  <- data.frame(x=1:length(bpm), y=bpm, col = abs(diff(col)))
# ggplot(data=df, aes(x=x,y=y,col=col))+geom_point()+
#   geom_smooth()+theme_mini(scale_text = 1.2, font = "Impact")+
#   labs(title="Instantaneous BPM of FDF", x="beats", y="BPM")

#ggsave("figs/bpm-wfd.png", width=6, height=3)

df  <- data.frame(x=1:length(bpm), y=bpm)
ggplot(data=df, aes(x=x,y=y))+geom_point(col = "#E41A1C",alpha=0.5)+
  stat_smooth(method=rlm,formula=y~ns(x,20),se=TRUE,level=0.95,span=0.2,n=2000,color="#377EB8", fill="#377EB8")+theme_mini(scale_text = 1.2, font = "Impact")+
  labs(title="Instantaneous BPM of Miles Teller\nin Whiplash (last scene)", x="beats", y="BPM")+
  ylim(0, 1200)

#ggsave("figs/bpm-whiplash-end.png", width=5, height=3)
