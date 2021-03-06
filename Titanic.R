#we have data on some passengers and we know some of who died
#the goal is to predict the survival for the passengers we do not have survival data of
# and explore the relationship between various factors and the survival outcome

#loading all the libraries needed for the analysis
library(ggplot2)
library(dplyr)
library(GGally)
library(rpart)
library(rpart.plot)
library(randomForest)

#read in the data sets and make a new data set based on the train and test data sets
test <- read.csv('/Users/judygitahi/Downloads/test.csv',stringsAsFactors = FALSE)
#this is the data for which we are predicting the survival 

train <- read.csv('/Users/judygitahi/Downloads/train.csv', stringsAsFactors = FALSE)
#has all info including whether the passenger died or not

#make a data set using the test and train data sets
full <- bind_rows(train,test)
LT=dim(train)[1]

#check the internal structure of the resulting data set
str(full)

# Missing values - I count the number of NAs per column, and number of empty strings
colSums(is.na(full))
colSums(full=="")

#change the empty strings in Embarked to the first choice "C"
full$Embarked[full$Embarked==""]="C"

#checking how many different types of vectors there are to determine which we can move from features to factors
apply(full,2, function(x) length(unique(x)))

# encoding some of the columns into factors (categorical variables)
cols<-c("Survived","Pclass","Sex","Embarked")
for (i in cols){
  full[,i] <- as.factor(full[,i])
}

str(full)

#what is the relationship between sex and survival?
ggplot(data=full[1:LT,],aes(x=Sex,fill=Survived))+geom_bar()

#then look at survival as a function of those who embarked and how that correlates to where you embarked
ggplot(data = full[1:LT,],aes(x=Embarked,fill=Survived))+geom_bar(position="fill")+ylab("Frequency")

t<-table(full[1:LT,]$Embarked,full[1:LT,]$Survived)
for (i in 1:dim(t)[1]){
  t[i,]<-t[i,]/sum(t[i,])*100
}
t
#It looks that you have a better chance to survive if you Embarked in 'C' (55% compared to 33% and 38%).

# Then look at survival as a function of Pclass:
ggplot(data = full[1:LT,],aes(x=Pclass,fill=Survived))+geom_bar(position="fill")+ylab("Frequency")
# Interestingly, it looks like you have a better chance to survive if you in lower ticket class.

# then do a more granular analysis and divide the graph by embarked and class
#the correlation between embarked and survived is no longer evident
ggplot(data = full[1:LT,],aes(x=Embarked,fill=Survived))+geom_bar(position="fill")+facet_wrap(~Pclass)

# So we look at survival as a function of SibSp and Parch
ggplot(data = full[1:LT,],aes(x=SibSp,fill=Survived))+geom_bar()
ggplot(data = full[1:LT,],aes(x=Parch,fill=Survived))+geom_bar()

# The dymanics of SibSp and Parch are very close one each other.-- but dont really give much information as a whole
# Let's try to look at another parameter: family size.

full$FamilySize <- full$SibSp + full$Parch +1;
full1<-full[1:LT,]
ggplot(data = full1[!is.na(full[1:LT,]$FamilySize),],aes(x=FamilySize,fill=Survived))+geom_histogram(binwidth =1,position="fill")+ylab("Frequency")
# That shows that families with a family size bigger or equal to 2 but less than 6 have a more than 50% to survive, in contrast to families with 1 member or more than 5 members. 

# Survival as a function of age:

ggplot(data = full1[!(is.na(full[1:LT,]$Age)),],aes(x=Age,fill=Survived))+geom_histogram(binwidth =3)
ggplot(data = full1[!is.na(full[1:LT,]$Age),],aes(x=Age,fill=Survived))+geom_histogram(binwidth = 3,position="fill")+ylab("Frequency")

# Children (younger than 15YO) and old people (80 and up) had a better chance to survive.

# Is there a correlation between Fare and Survivial?
ggplot(data = full[1:LT,],aes(x=Fare,fill=Survived))+geom_histogram(binwidth =20, position="fill")
full$Fare[is.na(full$Fare)] <- mean(full$Fare,na.rm=T)
# It seems like if your fare is bigger, than you have a better chance to survive.
sum(is.na(full$Age))
# There are a lot of missing values in the Age feature, so I'll put the mean instead of the missing values.
full$Age[is.na(full$Age)] <- mean(full$Age,na.rm=T)
sum(is.na(full$Age))

# The title of the passanger can affect his survive:
full$Title <- gsub('(.*, )|(\\..*)', '', full$Name)
full$Title[full$Title == 'Mlle']<- 'Miss' 
full$Title[full$Title == 'Ms']<- 'Miss'
full$Title[full$Title == 'Mme']<- 'Mrs' 
full$Title[full$Title == 'Lady']<- 'Miss'
full$Title[full$Title == 'Dona']<- 'Miss'
officer<- c('Capt','Col','Don','Dr','Jonkheer','Major','Rev','Sir','the Countess')
full$Title[full$Title %in% officer]<-'Officer'

full$Title<- as.factor(full$Title)

ggplot(data = full[1:LT,],aes(x=Title,fill=Survived))+geom_bar(position="fill")+ylab("Frequency")

# The train set with the important features 
train_im<- full[1:LT,c("Survived","Pclass","Sex","Age","Fare","SibSp","Parch","Title")]
ind<-sample(1:dim(train_im)[1],500) # Sample of 500 out of 891
train1<-train_im[ind,] # The train set of the model
train2<-train_im[-ind,] # The test set of the model

# Let's try to run a logistic regression
model <- glm(Survived ~.,family=binomial(link='logit'),data=train1)
summary(model)

# We can see that SibSp, Parch and Fare are not statisticaly significant. 
# Let's look at the prediction of this model on the test set (train2):
pred.train <- predict(model,train2)
pred.train <- ifelse(pred.train > 0.5,1,0)
# Mean of the true prediction 
mean(pred.train==train2$Survived)

t1<-table(pred.train,train2$Survived)
# Presicion and recall of the model
presicion<- t1[1,1]/(sum(t1[1,]))
recall<- t1[1,1]/(sum(t1[,1]))
presicion
recall
# F1 score
F1<- 2*presicion*recall/(presicion+recall)
F1
# F1 score on the initial test set is 0.871. This pretty good.

# Let's run it on the test set:

test_im<-full[LT+1:1309,c("Pclass","Sex","Age","SibSp","Parch","Fare","Title")]

pred.test <- predict(model,test_im)[1:418]
pred.test <- ifelse(pred.test > 0.5,1,0)
res<- data.frame(test$PassengerId,pred.test)
names(res)<-c("PassengerId","Survived")
write.csv(res,file="res.csv",row.names = F)

model_dt<- rpart(Survived ~.,data=train1, method="class")
rpart.plot(model_dt)

pred.train.dt <- predict(model_dt,train2,type = "class")
mean(pred.train.dt==train2$Survived)
t2<-table(pred.train.dt,train2$Survived)

presicion_dt<- t2[1,1]/(sum(t2[1,]))
recall_dt<- t2[1,1]/(sum(t2[,1]))
presicion_dt
recall_dt
F1_dt<- 2*presicion_dt*recall_dt/(presicion_dt+recall_dt)
F1_dt
# Let's run this model on the test set:
pred.test.dt <- predict(model_dt,test_im,type="class")[1:418]
res_dt<- data.frame(test$PassengerId,pred.test.dt)
names(res_dt)<-c("PassengerId","Survived")
write.csv(res_dt,file="res_dt.csv",row.names = F)

# Let's try to predict survival using a random forest.
model_rf<-randomForest(Survived~.,data=train1)
# Let's look at the error
plot(model_rf)
pred.train.rf <- predict(model_rf,train2)
mean(pred.train.rf==train2$Survived)
t1<-table(pred.train.rf,train2$Survived)
presicion<- t1[1,1]/(sum(t1[1,]))
recall<- t1[1,1]/(sum(t1[,1]))
presicion
recall
F1<- 2*presicion*recall/(presicion+recall)
F1
# Let's run this model on the test set:
pred.test.rf <- predict(model_rf,test_im)[1:418]
res_rf<- data.frame(test$PassengerId,pred.test.rf)
names(res_rf)<-c("PassengerId","Survived")
write.csv(res_rf,file="res_rf.csv",row.names = F)

