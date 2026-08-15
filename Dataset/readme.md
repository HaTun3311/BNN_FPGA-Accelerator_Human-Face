# 1.Dataset
Dataset Details: ORL face database composed of 400 images of size 112 x 92. There are 40 people, 10 images per person. The images were taken at different times, lighting and facial expressions. The faces are in an upright position in frontal view, with a slight left-right rotation. Link to the Dataset: https://www.dropbox.com/s/i7uzp5yxk7wruva/ORL_faces.npz?dl=0

# 2. Setup Library
import numpy as np <br>
import pandas as pd <br>
import matplotlib.pyplot as plt <br>

# 3. Read Dataset
- load dataset: <br>
data = np.load('../input/orlfaces/ORL_faces.npz') <br>
- load the "Train Images" <br>
x_train = data['trainX'] <br>
- normalize every image <br>
x_train = np.array(x_train,dtype='float32')/255 <br>
x_test = data['testX'] <br>
x_test = np.array(x_test,dtype='float32')/255 <br>
- load the Label of Images <br>
y_train= data['trainY'] <br>
y_test= data['testY'] <br>
- show the train and test Data format <br>
print('x_train : {}'.format(x_train[:])) <br> 
print('Y-train shape: {}'.format(y_train)) <br>
print('x_test shape: {}'.format(x_test.shape)) <br>
