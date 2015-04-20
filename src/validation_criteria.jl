validation_criteria(model::SALSAModel,X,Y,val_idx) = validation_criteria(model,X[val_idx,:],Y[val_idx])
validation_criteria(model::SALSAModel,X,Y) = model.sparsity_cv*mean(model.output.w .!= 0) + (1-model.sparsity_cv)*misclass(Y, predict_raw(model,X))