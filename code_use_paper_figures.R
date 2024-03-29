################################################################################
##### Use the code and re-produce figures from the Article######################
##### Trait-based prediction and control: a roadmap for community ecology  #####
########################################### Gauzere P. #########################

library(viridis) #because we like nice color scales
library(see)


############### A Predicting demographic model parameters ######################

#We will use the function predict_model_parameters()
#this basically implements the idea presented in 
#chapter "Predicting demographic model parameters" and Box 2b.

#load the function
source("predict_demographic_model_parameters.R")
  #read the forewords of the function to know how to use it

### we can play with different mechanisms and distributions
# predict coefficient under multiple hypotheses and trait distributions 
alpha.df <- predict_demographic_model_parameters(
  rep = 10,
  nsp = 10,
  env = seq(from = 0, to = 10, by = 0.1),
  trait.distribution = c("uniform","gaussian","poisson", "bimodal"),
  mechanism = c("niche difference", "competitive dominance", "extreme facilitation")
)

#plot all of it to compare
alpha.df %>% filter( i != j) %>% #remove intraspecific coefficient
  ggplot(aes(x=interaction.coef, fill=env, group = env))+
  geom_histogram()+
  theme_classic()+
  theme(legend.position="bottom")+
  scale_fill_viridis()+
  geom_vline(xintercept = 0, col = "darkgrey")+
  scale_x_continuous(expand = c(0,0))+
  scale_y_continuous(expand = c(0,0), trans= "sqrt")+
  facet_wrap(~ mechanism + trait.distribution)



##### Figure S2 #####
## we simulate 10replicates along a continuous environmental gradient 
# under the competitive dominance hypothesis of the niche difference
alpha.df <- predict_demographic_model_parameters(
  rep = 10,
  nsp = 10,
  env = seq(from = 0, to = 10, by = 5),
  trait.distribution = "uniform",
  mechanism = c("niche difference", "competitive dominance"))

alpha.df %>%  
ggplot(aes(x = i, y = j, fill=interaction.coef))+
  geom_raster() +
  scale_fill_viridis_c()+
  facet_wrap(~ env + mechanism, nrow = 5)+
  theme_void()+
  coord_equal()

############### B Scaling up to coexistence outcomes ######################

# We will use the function predict_coexistence_outcome()
# this basically implements the idea presented in 
# chapter "Scaling up to coexistence outcomes" and Box 2c

# load the function
source("predict_coexistence_outcome.R")
# read the forewords of the function to know how to use it

### plot networks #####
# we can use predict_demographic_model_parameters() with only 2 environmental values
# choose environmental value : env = 0  or env = 10
alpha.df <- predict_demographic_model_parameters(
  rep = 1,
  nsp = 10,
  env = c(0, 10),
  trait.distribution = "uniform",
  mechanism = "competitive dominance")

#then we use the function predict_coexistence_outcome() to plot the netwrok with "plot.netwrok=T"
#please read the forewords of the function predict_coexistence_outcome() 
alpha.df %>% 
  filter(env == 0) %>%
  predict_coexistence_outcome(plot.network = T, network.threshold = 0.05)
  
alpha.df %>% 
  filter(env == 10) %>%
  predict_coexistence_outcome(plot.network = T, network.threshold = 0.05)


#### the function compute a lot of network features and coexistence, but is time demanding 
# note that the resolution of the ODE sometimes won't be possible if you choose weird parameters
# keep it easy
# let's play
# we need a good environmental definition and trait coverage to interpolate coexistence outcome surface
alpha.df <- predict_demographic_model_parameters(
  rep = 100,
  nsp = 10,
  env = seq(from = 0, to = 10, by = 0.1))


# for computation purpose, we use tidyR and group_by() - group_modify(), but 
# you can use the function to loop on the different subset of alpha.df if you prefer

alpha.properties <-
    alpha.df %>%
    group_by(env, replicat) %>%
    group_modify( ~ predict_coexistence_outcome(.x,
                                                Nmin = 0.0001,
                                                initial.abundance = 0.01,
                                                growth.rate = "trait",
                                                n.time.step = 100,
                                                extinction = T,
                                                plot.dynamic = F,
                                                plot.network = F, 
                                                network.threshold = 0.05
                                                ))

## We can play to see links with community or matrix properties and coexistence outcomes

#feasibility only achieved at low environmental values (less stressful conditions)
ggplot(alpha.properties, aes(x = env, y = mean_trait))+
  geom_point(aes(col = numeric_feasibility, alpha = n_realized))+
  scale_color_viridis_d()+
  theme_classic()+
  theme(legend.position = "bottom")

# environment stress is linked with reduced richness and trait variability 
ggplot(alpha.properties, aes(x = env, y = mean_trait))+
  geom_point(aes(col = n_realized))+
  scale_color_viridis()+
  theme_classic()+
  theme(legend.position = "bottom")

# and the first moment of the mean interspecific interaction coefficient distribution is linked with realized community size 
ggplot(alpha.properties, aes(x = E1, y = n_realized))+
  geom_point()+
  scale_color_viridis_d()+
  theme_classic()

##### Figure 2 coexistence outcome surface  #####
# first, predict model parameters. It is better to have many replicates in order sample large variation in trait mean
#because they  are randomly sampled from distribution)
source("predict_demographic_model_parameters.R")

alpha.df <- predict_demographic_model_parameters(
  nsp = 10, 
  mechanism ="competitive dominance", 
  trait.distribution ="uniform",
  rep =100,
  env = seq(from = 0, to = 10, by = 0.1))

#then we can compute the coexistence outcome, but it can take a lot of time.
source("predict_coexistence_outcome.R")

# note that the coexistence outcomes are sensitive to initial conditions,
# so to deal with that I advice keeping initial.abundance = "random" and using a lot of replicates
alpha.properties <-
  alpha.df %>%
  group_by(env, replicat, trait.distribution, mechanism) %>%
  group_modify( ~ predict_coexistence_outcome(.x,
                                              Nmin = 0.0001,
                                              initial.abundance = "random",  
                                              growth.rate = "trait",
                                              n.time.step = 100,
                                              extinction = T,
                                              plot.dynamic = F,
                                              plot.network = F))

# To create figure 2, we interpolate the predicted over the full surface of trait - env
## feasability probability
library(akima)
feasibility_interpolation <-
  interp(
    alpha.properties$env,
    alpha.properties$mean_trait,
    as.factor(alpha.properties$analytic_feasibility),
    nx = 100,
    ny = 100,
    duplicate = "strip"
  )
li.zmin <- min(feasibility_interpolation$z,na.rm=TRUE)
li.zmax <- max(feasibility_interpolation$z,na.rm=TRUE)
breaks <- pretty(c(li.zmin,li.zmax),10)
colors <- viridis(length(breaks)-1)
with(feasibility_interpolation, image (x,y,z, breaks=breaks, col=colors))
# contour(feasibility_interpolation, levels=1.01, add=TRUE, col = "white")

##stability
stab_interpolation <-
  interp(
    alpha.properties$env,
    alpha.properties$mean_trait,
    as.factor(alpha.properties$analytic_stability),
    nx = 100,
    ny = 100,
    duplicate = "strip"
  )
li.zmin <- min(stab_interpolation$z,na.rm=TRUE)
li.zmax <- max(stab_interpolation$z,na.rm=TRUE)
breaks <- pretty(c(li.zmin,li.zmax),10)
colors <- viridis(length(breaks)-1)
with(stab_interpolation, image (x,y,z, breaks=breaks, col=colors))
# contour(stab_interpolation, levels=1.01, add=TRUE, col = "white")


##n_realized
n_interpolation <- interp(alpha.properties$env, alpha.properties$mean_trait, alpha.properties$n_realized, nx=100, ny=100, duplicate = "strip")
li.zmin <- min(n_interpolation$z,na.rm=TRUE)
li.zmax <- max(n_interpolation$z,na.rm=TRUE)
breaks <- pretty(c(li.zmin,li.zmax),10)
colors <- viridis(length(breaks)-1)
with(n_interpolation, image (x,y,z, breaks=breaks, col=colors, ylim = c(0.3, 0.7)))
# contour(n_interpolation, levels=breaks, add=TRUE)







############### C Predicting invasibility ############### 
 # We will use the function predict_invasibility()
 # this basically implements the idea presented in chapter "Predicting invasibility from trait×environment interactions"
 # load the function
 source("predicting_invasibility.R")
 # read the forewords of the function to know how to use it

##### Figure  3 #####
res_invasion <-
   predict_invasibility_surface(
     nsp = 10,
     env = seq(from = 1, to = 10, by = 1),
     trait.distribution = c("uniform"),
     mechanism = "niche difference",
     Nmin = 0.0001 ,
     initial.abundance = 0.0005 ,
     growth.rate = 0.5,
     n.time.step = 250,
     extinction = T,
     plot.invasion = T,
     traits_to_test = seq(0,1, 0.2), 
     plot.surface = T
   )

# to make the exact figure 3 increase the definition of traits_to_test and env vector by 10 

############### D Predicting environmental change response ###############

# here we are interested of the temporal dynamic of a given community
# in this case the environmental gradient is explicitely temporal
# Now, the echange in environment affect the interaction matrix via predict_demographic_model_parameter at each timesteps

##### simulate environmental change #####

# we use the function simulate_environmental_change(), which implements the basic principles of temporal ecology  
# proposed by Ryo et al., 2019 TREE
# read the function forewords for more details
source("simulate_environmental_change.R")

#plots talk more than words to describe what kind ot environmental changes can be simulated

###discrete events
simulate_environmental_change(type = "pulse")

simulate_environmental_change(type = "step")

simulate_environmental_change(type = "ramp")

### trajectory
#linear
simulate_environmental_change(type = "linear", trend_value = 2)
#linear with stochasticity
simulate_environmental_change(type = "linear", trend_value = 2, stochasticity_value = 1)

#cyclic
simulate_environmental_change(type = "cyclic", cycle_value = 3)

#cyclic with stochasticity
simulate_environmental_change(type = "cyclic", cycle_value = 3, stochasticity_value = 1)

#non-stationary (random walk)
simulate_environmental_change(type = "non-stationary", dispersion_value = 0.10)

#non-stationary (random walk) with stochasticity
simulate_environmental_change(type = "non-stationary", dispersion_value = 0.10, stochasticity_value = 1)

##### predict community response to environmental change #####
# after using simulate_environmental_change()
# We will use the function predict_environmental_change_response()
# load the function

source("simulate_environmental_change.R")
source("predict_environmental_change_response.R")
# read the forewords of the function to know how to use it

##### Figure  4 #####
#simulate linear temporal increase in environment 
linear_change <- simulate_environmental_change(n.time.step = 1000, type = "linear", trend_value = 3, plot.env.change = T)

pdf("predict_env_response.pdf", width= 4,  height = 6)
# choose mechanism = "competitive dominance" for Fig7a-b and mechanism = "niche difference" for Fig7c-d 
linear_change_response_nicheDiff <- predict_environmental_change_response(nsp = 10,
                                                                        env.change = linear_change,
                                                                        trait.distribution = "uniform",
                                                                        mechanism = "niche difference",
                                                                        Nmin = 0.001,
                                                                        initial.abundance = 0.005,
                                                                        growth.rate =0.5,
                                                                        extinction = T,
                                                                        plot.species.dynamics = F,
                                                                        plot.response.diagram = T)

linear_change_response_compDom <- predict_environmental_change_response(nsp = 10,
                                              env.change = linear_change,
                                              trait.distribution = "uniform",
                                              mechanism = "competitive dominance",
                                              Nmin = 0.001,
                                              initial.abundance = 0.005,
                                              growth.rate =0.5,
                                              extinction = T,
                                              plot.species.dynamics = F,
                                              plot.response.diagram = T)


cyclic.change <- simulate_environmental_change(n.time.step = 1000, type = "cyclic", cycle_value = 10, cycle_period = 0.025, plot.env.change = F)
cyclic_change_response_nicheDiff <- predict_environmental_change_response(nsp = 10,
                                                          env.change = cyclic.change,
                                                          trait.distribution = "uniform",
                                                          mechanism =  "niche difference",
                                                          Nmin = 0.001,
                                                          initial.abundance = 0.005,
                                                          growth.rate = 0.5,
                                                          extinction = T,
                                                          plot.species.dynamics = F,
                                                          plot.response.diagram = T)


cyclic_change_response_compDom <- predict_environmental_change_response(nsp = 10,
                                                                env.change = cyclic.change,
                                                                trait.distribution = "uniform",
                                                                mechanism =  "competitive dominance",
                                                                Nmin = 0.001,
                                                                initial.abundance = 0.005,
                                                                growth.rate = 0.5,
                                                                extinction = T,
                                                                plot.species.dynamics = F,
                                                                plot.response.diagram = T)


dev.off()

##### Figure  8 #####
cyclic.change <- simulate_environmental_change(type = "cyclic", cycle_value = 10, cycle_period = 0.05, 
                                               plot.env.change = F, 
                                               n.time.step=350)

cyclic_change_response <- predict_environmental_change_response(nsp = 10,
                                                                env.change = cyclic.change,
                                                                trait.distribution = "uniform",
                                                                mechanism = "niche difference",#"competitive dominance",
                                                                Nmin = 0.01,
                                                                initial.abundance = 0.01,
                                                                growth.rate = "trait",
                                                                extinction = T,
                                                                plot.species.dynamics = T,
                                                                plot.response.diagram = T)


g0 = ggplot(cyclic.change, aes(x=time,y=env.dynamic)) +
  geom_line(color='purple') + theme_classic()

g1 = ggplot(cyclic_change_response[[1]], aes(y = n, x = time)) +
  geom_line(aes(col = trait.i, group = i)) +
  scale_color_viridis() +
  theme_classic()+
  theme(legend.position = "bottom") +
  scale_y_sqrt()

g2 = ggplot(cyclic_change_response$detJ, aes(x=time,y=detJ)) +
  geom_line(color='red') + theme_classic()

ggarrange(g0,g1,g2, nrow=3)

forcingdet = cyclic.change %>% left_join(cyclic_change_response$detJ) %>% 
  left_join(cyclic_change_response$comm_dynamic %>% filter(i==3))

# note that the forcing and sensitivity of response are not aligned!
plot(detJ~n,data=forcingdet,type='l')

plot(scale(detJ)~time,data=forcingdet,type='l')
lines(scale(n)~time,data=forcingdet,type='l',col='red')

