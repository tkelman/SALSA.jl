function tune_algorithm_AFEm(X, Y, model::SALSAModel)
    # Renyi entropy calculations
    k = kernel_from_data_model(model.kernel,X)    
    rp = ceil(sqrt(size(X,1)*model.subset_size))
    num_k = length(fieldnames(model.kernel))
    X_subset = sub(X,entropy_subset(X,k,rp),:)
    
    cost_fun = x0 -> cross_validate_algorithm_AEFm(x0,X,Y,model,num_k,X_subset)
    par = run_global_opt(model,cost_fun,model.global_opt,(size(Y,2)*5+num_k,5))
    
    # set the output model mode correctly
    pars = num_k > 0 ? exp(par[end-num_k+1:end]) : []
    model.output.mode = NONLINEAR(pars,X_subset[:,:])
    # return model and the parameters
    model, par
end

function cross_validate_algorithm_AEFm(x0, X, Y, model, num_k, X_subset)
    pars = num_k > 0 ? exp(x0[end-num_k+1:end]) : []
    kernel = kernel_from_parameters(model.kernel,pars)    
    (eigvals,eigvec) = eig_AFEm(X_subset, kernel)
    
    # perform cross-validation by a generic and parallelizable function
    gen_cross_validate(X, Y, model) do Xtr, Ytr, Xval, Yval
        # perform Automatic Feature Extraction by Nystrom approximation 
        features_train = AFEm(eigvals,eigvec,X_subset,kernel,Xtr)
        features_valid = AFEm(eigvals,eigvec,X_subset,kernel,Xval)        
        # run algorithm        
        w_ = zeros(size(features_train,2),size(Ytr,2)) 
        b_ = zeros(size(Ytr,2))'

        for k in 1:size(Ytr,2)
            # generate model from the partitioned parameters
            model = model_from_parameters(model,partition_pars(x0,k))
            # run algorithm for the excluded subset of validation indices        
            w_[:,k], b_[:,k] = run_algorithm(features_train,Ytr[:,k],model)
        end
        
        model.output.w = w_; model.output.b = b_ 
        validation_criteria(model,features_valid,Yval)
    end
end