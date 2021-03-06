function reweighted_l2rda_alg(dfunc::Function, X, Y, λ::Float64, ɛ::Float64, varɛ::Float64, 
                              k::Int, max_iter::Int, tolerance::Float64, online_pass=0, train_idx=[])

    # Internal function for a simple Reweighted l2-RDA routine
    #
    # Copyright (c) 2015, KU Leuven-ESAT-STADIUS, License & help @
    # http://www.esat.kuleuven.be/stadius/ADB/jumutc/softwareSALSA.php

    N = size(X,1)
    d = size(X,2) + 1
    check = ~issparse(X)
    rw = ones(d)
    
    if check
        g = zeros(d,1)
        w = rand(d,1)/100
        sub_arr = (I) -> [sub(X,I,:) ones(k,1)]'
    else      
        g = spzeros(d,1)
        total = length(X.nzval)
        w = sprand(d,1,total/(N*d))/100
        fg = i -> -1./(λ .+ rw[i])
        X = [X'; sparse(ones(1,N))]
        sub_arr = (I) -> X[:,I]
    end

    if ~isempty(train_idx)
        space = train_idx
        N = size(space,1)
    else
        space = 1:1:N
    end

    if online_pass > 0
        max_iter = N*online_pass
        smpl = (t,k) -> begin
            s = t % N 
            s > 0 ? s : N
        end
    else
        pd = Categorical(N)
        smpl = (t,k) -> rand(pd,k)
    end

    for t=1:max_iter 
        idx = space[smpl(t,k)]
        w_prev = w

        yt = Y[idx]
        At = sub_arr(idx)

        # calculate dual average: gradient
        g = ((t-1)/t).*g + (1/(t)).*dfunc(At,yt,w)
        
        # find a close form solution
        # update re-weighting vector
        if check     
            w = -(1./(λ .+ rw)).*g       
            rw = 1 ./ (w.^2 .+ ɛ)
        else 
            # do not perform sparse(...) and filter and map over SparceMatrixCSC
            # because Garbage Collection performs realy badly in the tight loops
            w = SparseMatrixCSC(d,1,g.colptr,g.rowval,fg(g.rowval)).*g
            rw[g.rowval] = 1./(ɛ .+ w.nzval.^2)
        end
        
        # check the stopping criteria w.r.t. Tolerance, check, online_pass
        if online_pass == 0 && check && vecnorm(w - w_prev) < tolerance
            break
        end
    end

    # truncate solution
    if check
        w[abs(w).<=varɛ] = 0
    else
        ind = abs(w.nzval) .> varɛ
        w = reduce_sparsevec(w,find(ind))
    end

    w[1:end-1], w[end]
end