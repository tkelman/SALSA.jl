function reweighted_l1rda_alg(dfunc::Function, X, Y, λ::Float64, γ::Float64, ρ::Float64, ɛ::Float64,
                              k::Int, max_iter::Int, tolerance::Float64, online_pass=0, train_idx=[])

    # Internal function for a simple l1-RDA routine
    #
    # Copyright (c) 2015, KU Leuven-ESAT-STADIUS, License & help @
    # http://www.esat.kuleuven.be/stadius/ADB/jumutc/softwareSALSA.php

    N = size(X,1)
    d = size(X,2) + 1
    check = ~issparse(X)
    
    
    if check
        g = zeros(d)
        rw = ones(d)
        w = rand(d,1)/100
        sub_arr = (I) -> [sub(X,I,:) ones(k,1)]'
    else 
        g = spzeros(d,1)
        total = length(X.nzval)
        w = sprand(d,1,total/(N*d))/100
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
        if check
            λ_rda = rw*λ .+ (ρ*γ)/sqrt(t)
            w = -(sqrt(t)/γ).*(g - λ_rda.*sign(g))
            w[abs(w).<=λ_rda] = 0
            rw = 1 ./ (abs(w) .+ ɛ)
        else
            # do not perform sparse(...) and filter and map over SparceMatrixCSC
            # because Garbage Collection performs realy badly in the tight loops
            λ_f = (v) -> λ./(abs(v) .+ ɛ) .+ (ρ*γ)/sqrt(t)
            gs = SparseMatrixCSC(d,1,g.colptr,g.rowval,sign(g.nzval))
            λ_rda = SparseMatrixCSC(d,1,w.colptr,w.rowval,λ_f(w.nzval))
            w = -(sqrt(t)/γ).*(g - λ_rda.*gs); I,J,V = findnz(g)
            ind = abs(V) .> λ_f(full(w_prev[I])) 
            w = reduce_sparsevec(w,find(ind))
        end

        # check the stopping criteria w.r.t. Tolerance, check, online_pass
        if online_pass == 0 && check && vecnorm(w - w_prev) < tolerance
            break
        end
    end

    w[1:end-1], w[end]
end