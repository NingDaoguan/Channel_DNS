MODULE FIELD
    USE GLOBAL_PARAMETER
    USE MESH
    USE MATH

    IMPLICIT NONE
    
    REAL, SAVE, ALLOCATABLE :: U(:, :, :), V(:, :, :), W(:, :, :), P(:, :, :)
    REAL, SAVE, ALLOCATABLE :: DU(:, :, :), DV(:, :, :), DW(:, :, :), DP(:, :, :)
    COMPLEX, SAVE, ALLOCATABLE :: DIVS(:, :, :), DPS(:, :, :), PBS(:, :, :)

    REAL, SAVE, ALLOCATABLE :: PB_VEL(:, :, :), PB_VIS(:, :, :), PB(:, :, :)
    REAL, SAVE, ALLOCATABLE :: DUHIST(:, :, :), DVHIST(:, :, :), DWHIST(:, :, :), DPHIST(:, :, :)
    REAL, SAVE, ALLOCATABLE, TARGET :: R(:, :, :)
    REAL, SAVE, POINTER :: R1(:, :, :), R2(:, :, :), R3(:, :, :), RP(:, :, :)
    REAL, SAVE, ALLOCATABLE :: DIV(:, :, :)
    
    REAL, SAVE :: PGX, PGY, PGZ
    REAL, SAVE :: XFLOW, ZFLOW
    REAL, SAVE :: DIVMAX
    REAL, SAVE :: CFLMAX
    
    !DEBUG INFO
    INTEGER SOLVE_ITER
    
    !SUPPLIMENTAL VECTOR
    !FACTOR VECTOR FOR TD & CTD SOLVER
    REAL, SAVE, ALLOCATABLE :: NMFAC(:), NCFAC(:), NPFAC(:)
    COMPLEX, SAVE, ALLOCATABLE :: PMFAC(:), PCFAC(:), PPFAC(:)
    LOGICAL, SAVE :: FAC_ALLOCATED = .FALSE.
    INTEGER, SAVE :: FAC_LEN
    
    LOGICAL, SAVE :: ALL_ALLOCATED = .FALSE.
    
    PRIVATE ALL_ALLOCATED, DU, DV, DW, DP, R, R1, R2, R3, RP
    PRIVATE NMFAC, NCFAC, NPFAC, FAC_ALLOCATED, FAC_LEN
    PRIVATE DIVS, DPS, PB, PBS, PB_VEL, PB_VIS
    PRIVATE DUHIST, DVHIST, DWHIST, DPHIST
    
    CONTAINS
    
    SUBROUTINE ALLOC_FIELD()
        IMPLICIT NONE
        ALLOCATE(U(N1, 0:N2+1, N3))
        ALLOCATE(V(N1, 1:N2+1, N3))
        ALLOCATE(W(N1, 0:N2+1, N3))
        ALLOCATE(P(N1, N2, N3))
        ALLOCATE(DIV(N1, N2, N3))
        ALLOCATE(DU(N1, 0:N2+1, N3))
        ALLOCATE(DV(N1, 1:N2+1, N3))
        ALLOCATE(DW(N1, 0:N2+1, N3))
        ALLOCATE(DP(N1, N2, N3))
        ALLOCATE(DPS(N1, N2, N3))
        ALLOCATE(PB(N1, 2, N3))
        ALLOCATE(PB_VEL(N1, 2, N3))
        ALLOCATE(PB_VIS(N1, 2, N3))
        ALLOCATE(PBS(N1, 2, N3))
        ALLOCATE(DIVS(N1, N2, N3))
        ALLOCATE(DUHIST(N1, 0:N2+1, N3))
        ALLOCATE(DVHIST(N1, 1:N2+1, N3))
        ALLOCATE(DWHIST(N1, 0:N2+1, N3))
        ALLOCATE(DPHIST(N1, N2, N3))
        ALLOCATE(R(N1, N2, N3))
        ALL_ALLOCATED = .TRUE.
    END SUBROUTINE ALLOC_FIELD
    
    SUBROUTINE DEALLOC_FIELD()
        IMPLICIT NONE
        DEALLOCATE(U, V, W, P, DIV)
        DEALLOCATE(DU, DV, DW, DP)
        DEALLOCATE(DPS, PB, PB_VEL, PB_VIS, PBS, DIVS)
        DEALLOCATE(DUHIST, DVHIST, DWHIST, DPHIST)
        DEALLOCATE(R)
        ALL_ALLOCATED = .FALSE.
    END SUBROUTINE DEALLOC_FIELD
    
    SUBROUTINE ALLOC_FAC(N)
        IMPLICIT NONE
        
        INTEGER, INTENT(IN) :: N
        
        IF(FAC_ALLOCATED) THEN
            IF(N > FAC_LEN) THEN
                DEALLOCATE(NMFAC, NCFAC, NPFAC)
                DEALLOCATE(PMFAC, PCFAC, PPFAC)
                ALLOCATE(NMFAC(N))
                ALLOCATE(NCFAC(N))
                ALLOCATE(NPFAC(N))
                ALLOCATE(PMFAC(N))
                ALLOCATE(PCFAC(N))
                ALLOCATE(PPFAC(N))
                FAC_LEN = N
            END IF
        ELSE
            ALLOCATE(NMFAC(N))
            ALLOCATE(NCFAC(N))
            ALLOCATE(NPFAC(N))
            ALLOCATE(PMFAC(N))
            ALLOCATE(PCFAC(N))
            ALLOCATE(PPFAC(N))
            FAC_LEN = N
            FAC_ALLOCATED = .TRUE.
        END IF
        NMFAC = 0
        NCFAC = 0
        NPFAC = 0
        PMFAC = 0
        PCFAC = 0
        PPFAC = 0
    END SUBROUTINE ALLOC_FAC
    
    SUBROUTINE DEALLOC_FAC()
        IMPLICIT NONE
        IF(FAC_ALLOCATED) THEN
            DEALLOCATE(NMFAC, NCFAC, NPFAC)
            DEALLOCATE(PMFAC, PCFAC, PPFAC)
            FAC_LEN = 0
        END IF
    END SUBROUTINE DEALLOC_FAC
    
    SUBROUTINE INIUP()
        IMPLICIT NONE
        
        REAL V1M, V2M, V3M  !MEAN FLOW
        REAL S1, S2, S3     !SLICE AREA
        REAL YH
        REAL RFLOW
        
        INTEGER I, J, K
        
        !CHECK IF ALLOCATED
        IF(.NOT. ALL_ALLOCATED) CALL ALLOC_FIELD()
        
        CALL RANDOM_SEED()
        CALL RANDOM_NUMBER(U)
        CALL RANDOM_NUMBER(V)
        CALL RANDOM_NUMBER(W)
        
        !UNIFORM DISTRIBUTE IN [-0.5, 0.5)
        U = U - 0.5 
        V = V - 0.5
        W = W - 0.5
        
        !IMPOSE ZERO VELOCITY AT BOUNDARY
        U(:, 0, :) = 0
        V(:, 1, :) = 0
        W(:, 0, :) = 0
        U(:, N2+1, :) = 0
        V(:, N2+1, :) = 0
        W(:, N2+1, :) = 0
        
        !ELIMINATE MEAN QUANTITIES OF RANDOM FLUCTUATIONS
        !U DIRECTION
        DO I = 1, N1
            V1M = 0
            S1 = 0
            DO K = 1, N3
                DO J = 1, N2
                    S1 = S1 + DY(J) * DZ * (1 + GETETA(X(I - 1), Z(K - 1), T))
                    V1M = V1M + U(I, J, K) * DY(J) * DZ * (1 + GETETA(X(I - 1), Z(K - 1), T))
                END DO
            END DO
            V1M = V1M / S1
            U(I, 1:N2, :) = U(I, 1:N2, :) - V1M
        END DO
        
        !V DIRECTION
        DO J = 2, N2
            V2M = 0
            S2 = 0
            DO K = 1, N3
                DO I = 1, N1
                    S2 = S2 + DX * DZ
                    V2M = V2M + V(I, J, K) * DX * DZ
                END DO
            END DO
            V2M = V2M / S2
            V(:, J, :) = V(:, J, :) - V2M
        END DO
        
        !W DIRECTION
        DO K = 1, N3
            V3M = 0
            S3 = 0
            DO J = 1, N2
                DO I = 1, N1
                    S3 = S3 + DY(J) * DX * (1 + GETETA(X(I - 1), Z(K - 1), T))
                    V3M = V3M + W(I, J, K) * DY(J) * DX * (1 + GETETA(X(I - 1), Z(K - 1), T))
                END DO
            END DO
            V3M = V3M / S3
            W(:, 1:N2, K) = W(:, 1:N2, K) - V3M
        END DO
        
        U = U * INIT_TURB_INTENSITY * 2
        V = V * INIT_TURB_INTENSITY * 2
        W = W * INIT_TURB_INTENSITY * 2
        
        !IMPOSE LAMINAR VELOCITY PROFIELS IN U VELOCITIES
        DO J = 1, N2
            YH = (Y(J) + Y(JM(J))) / 2
            U(:, J, :) = U(:, J, :) + 1 - YH * YH
        END DO
        
        RFLOW = 4.0 / 3.0 * LZ !INTEGRAL OF U ALONG Y
        CALL CHECK_FLOW_RATE()
        U = RFLOW / XFLOW * U
        W(:, 1:N2, :) = W(:, 1:N2, :) - ZFLOW / LX / LY
        
        !IMPOSE ZERO-PRESSURE FLUCTUATIONS
        P = 0
        
        !INITIAL MEAN PRESSURE GRADIENT AT LAMINAR FLOW FIELD
        PGX = -2 / RE
        PGZ = 0
    END SUBROUTINE INIUP
    
    SUBROUTINE INIUP_FILE(PATH)
        IMPLICIT NONE
        CHARACTER(LEN = *), INTENT(IN) :: PATH
        CHARACTER(LEN = 256) U_PATH, P_PATH, PG_PATH
        INTEGER I, J, K
        
        U = 0
        V = 0
        W = 0
        U_PATH = TRIM(ADJUSTL(PATH))//'U.DAT'
        P_PATH = TRIM(ADJUSTL(PATH))//'P.DAT'
        PG_PATH = TRIM(ADJUSTL(PATH))//'PG.DAT'
        OPEN(301, FILE = U_PATH, FORM = 'BINARY')
        READ(301) (((U(I, J, K), I = 1, N1), J = 1, N2), K = 1, N3)
        READ(301) (((V(I, J, K), I = 1, N1), J = 1, N2), K = 1, N3)
        READ(301) (((W(I, J, K), I = 1, N1), J = 1, N2), K = 1, N3)
        CLOSE(301)
        OPEN(302, FILE = P_PATH, FORM = 'BINARY')
        READ(302) (((P(I, J, K), I = 1, N1), J = 1, N2), K = 1, N3)
        CLOSE(302)
        OPEN(303, FILE = PG_PATH)
        READ(303, *) PGX, PGZ
        CLOSE(303)
        CALL CHECK_FLOW_RATE
    END SUBROUTINE INIUP_FILE
    
    SUBROUTINE CHECK_FLOW_RATE()
        IMPLICIT NONE
        
        REAL, ALLOCATABLE :: XMF(:), ZMF(:)
        REAL XC, ZC
        INTEGER I, J, K
        
        ALLOCATE(XMF(N1))
        ALLOCATE(ZMF(N3))
        
        DO I = 1, N1
            XMF(I) = 0
            XC = X(I - 1)
            DO K = 1, N3
                ZC = (Z(K) + Z(K - 1)) / 2
                DO J = 1, N2
                    XMF(I) = XMF(I) + U(I, J, K) * DZ * DY(J) * (1 + GETETA(XC, ZC, T))
                END DO
            END DO
        END DO
        
        DO K = 1, N3
            ZMF(K) = 0
            ZC = Z(K - 1)
            DO I = 1, N1
                XC = (X(I) + X(I - 1)) / 2
                DO J = 1, N2
                    ZMF(K) = ZMF(K) + W(I, J, K) * DX * DY(J) * (1 + GETETA(X(I - 1), Z(K - 1), T))
                END DO
            END DO
        END DO
        
        XFLOW = SUM(XMF) / N1
        ZFLOW = SUM(ZMF) / N3
        
    END SUBROUTINE CHECK_FLOW_RATE
        
    SUBROUTINE CHECK_DIV()
        IMPLICIT NONE
        
        CALL GETDIV(U, V, W, DIV, T)
        DIVMAX = MAXVAL(ABS(DIV))
    END SUBROUTINE CHECK_DIV
    
    SUBROUTINE GETDIV(UU, VV, WW, DDIV, TT)
        IMPLICIT NONE
        REAL, INTENT(IN) :: UU(:, 0:, :), VV(:, :, :), WW(:, 0:, :), TT
        REAL, INTENT(OUT) :: DDIV(:, :, :)
        REAL XC, YC, ZC
        REAL DUDY, DVDY, DWDY
        REAL U1, U2, U3, W1, W2, W3
        INTEGER I, J, K
        
        DO K = 1, N3
            ZC = (Z(K - 1) + Z(K)) / 2
            DO J = 1, N2
                YC = (Y(J - 1) + Y(J)) / 2
                DO I = 1, N1
                    XC = (X(I - 1) + X(I)) / 2
                    !DUDY = ((UU(I, JP(J), K) + UU(IP(I), JP(J), K)) / 2   &
                    !     -  (UU(I, J, K) + UU(IP(I), J, K)) / 2) / H(JP(J))
                    !DVDY = (VV(I, JP(J), K) - VV(I, J, K)) / DY(J)
                    !DWDY = ((WW(I, JP(J), K) + WW(I, JP(J), KP(K))) / 2   &
                    !     -  (WW(I, J, K) + WW(I, J, KP(K))) / 2) / H(JP(J))
                    U1 = (UU(I, JP(J), K) + UU(IP(I), JP(J), K)) / 2
                    U2 = (UU(I, J, K) + UU(IP(I), J, K)) / 2
                    U3 = (UU(I, JM(J), K) + UU(I, JM(J), K)) / 2
                    DUDY = U1 * DYH(1, J) + U2 * DYH(2, J) + U3 * DYH(3, J)
                    W1 = (WW(I, JP(J), K) + WW(I, JP(J), KP(K))) / 2
                    W2 = (WW(I, J, K) + WW(I, J, KP(K))) / 2
                    W3 = (WW(I, JM(J), K) + WW(I, JM(J), KP(K))) / 2
                    DWDY = W1 * DYH(1, J) + W2 * DYH(2, J) + W3 * DYH(3, J)
                    DVDY = (VV(I, JP(J), K) - VV(I, J, K)) / DY(J)
                    DDIV(I, J, K) = (UU(IP(I), J, K) - UU(I, J, K)) / DX    &
                                  + (VV(I, JP(J), K) - VV(I, J, K)) / DY(J) &
                                  + (WW(I, J, KP(K)) - WW(I, J, K)) / DZ    &
                                  + PHI1(XC, YC, ZC, TT) * DUDY            &
                                  + PHI2(XC, YC, ZC, TT) * DVDY            &
                                  + PHI3(XC, YC, ZC, TT) * DWDY
                END DO
            END DO
        END DO
    END SUBROUTINE GETDIV
    
    SUBROUTINE CHECK_CFL()
        IMPLICIT NONE
        
        REAL CFL
        REAL ETA
        INTEGER I, J, K
        REAL XC, ZC
        
        CFLMAX = 0
        DO K = 1, N3
            ZC = (Z(K) + Z(K - 1)) / 2
            DO J = 1, N2
                DO I = 1, N1
                    XC  = (X(I) + X(I - 1)) / 2
                    ETA = GETETA(XC, ZC, T)
                    
                    CFL = ABS(U(I, J, K) + U(IP(I), J, K)) * 0.5 / DX   &
                        + ABS(V(I, J, K) + V(I, JP(J), K)) * 0.5 / (DY(J) * (1 + ETA))   &
                        + ABS(W(I, J, K) + W(I, J, KP(K))) * 0.5 / DZ
                    
                    CFLMAX = MAX(CFL, CFLMAX)
                END DO
            END DO
        END DO
    END SUBROUTINE CHECK_CFL
    
    SUBROUTINE SOLVEUP()
        IMPLICIT NONE
        CALL UPDATE_MESH
        CALL GETVEL()
        CALL GETPRE()
        CALL UPDATE_UP()
    END SUBROUTINE SOLVEUP
    
    SUBROUTINE GETVEL()
        IMPLICIT NONE
        
        INTEGER :: ITER
        REAL :: ERR = 0
        
        ITER = 0
        CALL UPDATE_VB()
        
        DO WHILE(.TRUE.)
            DUHIST = DU
            DVHIST = DV
            DWHIST = DW
        
            CALL GETU()
            CALL GETV()
            CALL GETW()
            CALL FINISH_VEL(ERR)
            ITER = ITER + 1
            PRINT*, 'ERR : ', ERR
            IF(ERR < MAX_SOLVE_ERR .OR. ITER > MAX_SOLVE_ITER) EXIT
        END DO

        SOLVE_ITER = ITER
        DU = DU + U
        DV = DV + V
        DW = DW + W
        
    END SUBROUTINE GETVEL
    
    SUBROUTINE UPDATE_VB()
        IMPLICIT NONE
        INTEGER I, K
        REAL V1, V2, XC, ZC
        
        DU = 0
        DV = 0
        DW = 0
        
        !WARNING : ALL BOUNDARY VELOCITY ASSUMES AMPTITUDE IS LINEARLY INCREASED (A_tt = 0)
        
        DO K = 1, N3
            ZC = (Z(K) + Z(K - 1)) / 2
            DO I = 1, N1
                XC = (X(I) + X(I - 1)) / 2
                
                !DOWN WALL VELOCITY
                V1 = DDT_DN_AMPX * SIN(DN_WAVE_NUMX * XC - DN_WAVE_PSDX * T)    &
                   - DN_WAVE_AMPX * DN_WAVE_PSDX * COS(DN_WAVE_NUMX * XC - DN_WAVE_PSDX * T)   &
                   + DDT_DN_AMPZ * SIN(DN_WAVE_NUMZ * ZC - DN_WAVE_PSDZ * T)    &
                   - DN_WAVE_AMPZ * DN_WAVE_PSDZ * COS(DN_WAVE_NUMZ * ZC - DN_WAVE_PSDZ * T)
                V2 = DDT_DN_AMPX * SIN(DN_WAVE_NUMX * XC - DN_WAVE_PSDX * (T + DT))     &
                   - DN_WAVE_AMPX * DN_WAVE_PSDX * COS(DN_WAVE_NUMX * XC - DN_WAVE_PSDX * (T + DT))   &
                   + DDT_DN_AMPZ * SIN(DN_WAVE_NUMZ * ZC - DN_WAVE_PSDZ * (T + DT))     &
                   - DN_WAVE_AMPZ * DN_WAVE_PSDZ * COS(DN_WAVE_NUMZ * ZC - DN_WAVE_PSDZ * (T + DT))
                DV(I, 1, K) = V2 - V1
                
                !UP WALL VELOCITY
                V1 = DDT_UP_AMPX * SIN(UP_WAVE_NUMX * XC - UP_WAVE_PSDX * T)    &
                   - UP_WAVE_AMPX * UP_WAVE_PSDX * COS(UP_WAVE_NUMX * XC - UP_WAVE_PSDX * T)   &
                   + DDT_UP_AMPZ * SIN(UP_WAVE_NUMZ * ZC - UP_WAVE_PSDZ * T)    &
                   - UP_WAVE_AMPZ * UP_WAVE_PSDZ * COS(UP_WAVE_NUMZ * ZC - UP_WAVE_PSDZ * T)
                V2 = DDT_UP_AMPX * SIN(UP_WAVE_NUMX * XC - UP_WAVE_PSDX * (T + DT))     &
                   - UP_WAVE_AMPX * UP_WAVE_PSDX * COS(UP_WAVE_NUMX * XC - UP_WAVE_PSDX * (T + DT))   &
                   + DDT_UP_AMPZ * SIN(UP_WAVE_NUMZ * ZC - UP_WAVE_PSDZ * (T + DT))     &
                   - UP_WAVE_AMPZ * UP_WAVE_PSDZ * COS(UP_WAVE_NUMZ * ZC - UP_WAVE_PSDZ * (T + DT))
                DV(I, N2+1, K) = V2 - V1
            END DO
        END DO
        
        !PRESSURE BOUNDARY
        DO K = 1, N3
            ZC = (Z(K) + Z(K - 1)) / 2
            DO I = 1, N1
                XC = (X(I) + X(I - 1)) / 2
                
                !DOWN WALL D_V / D_T
                PB_VEL(I, 1, K) = (DDT_DN_AMPX * DN_WAVE_PSDX * COS(DN_WAVE_NUMX * XC - DN_WAVE_PSDX * (T + DT))    &
                            +  DDT_DN_AMPZ * DN_WAVE_PSDZ * COS(DN_WAVE_NUMZ * ZC - DN_WAVE_PSDZ * (T + DT))) * -2.0&
                            -  DN_WAVE_PSDX ** 2 * DN_WAVE_AMPX * SIN(DN_WAVE_NUMX * XC - DN_WAVE_PSDX * (T + DT))  &
                            -  DN_WAVE_PSDZ ** 2 * DN_WAVE_AMPZ * SIN(DN_WAVE_NUMZ * ZC - DN_WAVE_PSDZ * (T + DT))
                PB_VEL(I, 1, K) = -PB_VEL(I, 1, K) / (1 + PHI2(XC, Y(0), ZC, T + DT))
                
                !UP WALL D_V / D_T
                PB_VEL(I, 2, K) = (DDT_UP_AMPX * UP_WAVE_PSDX * COS(UP_WAVE_NUMX * XC - UP_WAVE_PSDX * (T + DT))    &
                            +  DDT_UP_AMPZ * UP_WAVE_PSDZ * COS(UP_WAVE_NUMZ * ZC - UP_WAVE_PSDZ * (T + DT))) * -2.0&
                            -  UP_WAVE_PSDX ** 2 * UP_WAVE_AMPX * SIN(UP_WAVE_NUMX * XC - UP_WAVE_PSDX * (T + DT))  &
                            -  UP_WAVE_PSDZ ** 2 * UP_WAVE_AMPZ * SIN(UP_WAVE_NUMZ * ZC - UP_WAVE_PSDZ * (T + DT))
                PB_VEL(I, 2, K) = -PB_VEL(I, 2, K) / (1 + PHI2(XC, Y(N2), ZC, T + DT))
            END DO
        END DO
        
    END SUBROUTINE UPDATE_VB
    
    SUBROUTINE UPDATE_PB
        IMPLICIT NONE
        INTEGER I, K
        REAL XC, ZC, TT
        REAL D2FAC, DFAC, DVDY, D2VDY
        
        TT = T + DT
        
        DO K = 1, N3
            ZC = (Z(K) + Z(K - 1)) / 2
            DO I = 1, N1
                XC = (X(I) + X(I - 1)) / 2
                
                D2FAC = 1 + 2 * PHI2(XC, -1., ZC, TT)    &
                      + PHI1(XC, -1., ZC, TT) ** 2       &
                      + PHI2(XC, -1., ZC, TT) ** 2       &
                      + PHI3(XC, -1., ZC, TT) ** 2
                
                DFAC = PHI1(XC, -1., ZC, TT) * DPHI1DY(XC, -1., ZC, TT)   &
                     + PHI2(XC, -1., ZC, TT) * DPHI2DY(XC, -1., ZC, TT)   &
                     + PHI3(XC, -1., ZC, TT) * DPHI3DY(ZC, -1., ZC, TT)   &
                     + DPHI1DX(XC, -1., ZC, TT) + DPHI2DY(XC, -1., ZC, TT)&
                     + DPHI3DZ(XC, -1., ZC, TT)
                
                DVDY = (V(I, 2, K) - V(I, 1, K)) / DY(1)
                D2VDY = V(I, 3, K) * DYDY(1, 2) + V(I, 2, K) * DYDY(2, 2) + V(I, 1, K) * DYDY(3, 2)
                
                PB_VIS(I, 1, K) = (DVDY * DFAC + D2VDY * D2FAC) / (1 + PHI2(XC, -1., ZC, TT))
            END DO
        END DO
        
        DO K = 1, N3
            ZC = (Z(K) + Z(K - 1)) / 2
            DO I = 1, N1
                XC = (X(I) + X(I - 1)) / 2
                
                D2FAC = 1 + 2 * PHI2(XC, 1., ZC, TT) &
                      + PHI1(XC, 1., ZC, TT) ** 2    &
                      + PHI2(XC, 1., ZC, TT) ** 2    &
                      + PHI3(XC, 1., ZC, TT) ** 2
                
                DFAC = PHI1(XC, 1., ZC, TT) * DPHI1DY(XC, 1., ZC, TT) &
                     + PHI2(XC, 1., ZC, TT) * DPHI2DY(XC, 1., ZC, TT) &
                     + PHI3(XC, 1., ZC, TT) * DPHI3DY(XC, 1., ZC, TT) &
                     + DPHI1DX(XC, 1., ZC, TT) + DPHI2DY(XC, 1., ZC, TT) &
                     + DPHI3DZ(XC, 1., ZC, TT)
                
                DVDY = (V(I, N2+1, K) - V(I, N2, K)) / DY(N2)
                D2VDY = V(I, N2+1, K) * DYDY(1, N2) + V(I, N2, K) * DYDY(2, N2) + V(I, N2-1, K) * DYDY(3, N2)
                
                PB_VIS(I, 2, K) = (DVDY * DFAC + D2VDY * D2FAC) / (1 + PHI2(XC, 1., ZC, TT))
            END DO
        END DO
        
        PB = PB_VIS + PB_VEL
        CALL FFT(PB, PBS)
    END SUBROUTINE UPDATE_PB
    
    SUBROUTINE GETPRE()
        IMPLICIT NONE
        
        INTEGER :: ITER
        REAL :: ERR = 0
        
        ITER = 0
        DPHIST = DP
        
        DO WHILE(.TRUE.)
            CALL UPDATE_PB
            CALL FORM_RP
            CALL SOLVE_DP
            CALL UPDATE_UP
            !PRINT*, 'MAXVAL DU - U :', MAXVAL(ABS(DU - U))
            DU = U
            DV = V
            DW = W
            ITER = ITER + 1
            CALL CHECK_DIV
            !PRINT*, 'MAXDIV : ', MAXVAL(ABS(DIV)), MAXLOC(ABS(DIV))
            ERR = MAXVAL(ABS(DP - DPHIST))
            !PRINT*, 'PERR : ', ERR, MAXLOC(ABS(DP - DPHIST))
            IF(ERR < MAX_SOLVE_ERR .OR. ITER > MAX_SOLVE_ITER) EXIT
            DPHIST = DP
        END DO
        PB = PB
        CALL UPDATE_UP
        CALL CHECK_DIV
        !PRINT*, 'MAXDIV : ', MAXVAL(ABS(DIV))
        CALL OUTPUT
        SOLVE_ITER = SOLVE_ITER + ITER
        
    END SUBROUTINE GETPRE
    
    SUBROUTINE GETU()
        IMPLICIT NONE
        CALL FORM_R1()
        CALL SOLVE_UH()
    END SUBROUTINE GETU
    
    SUBROUTINE GETV()
        IMPLICIT NONE
        CALL FORM_R2()
        CALL SOLVE_VH()
    END SUBROUTINE GETV
    
    SUBROUTINE GETW()
        IMPLICIT NONE
        CALL FORM_R3()
        CALL SOLVE_WH()
    END SUBROUTINE GETW
    
    SUBROUTINE FINISH_VEL(ERR)
        IMPLICIT NONE
        REAL, INTENT(OUT) :: ERR
        
        REAL V1, V2, W1, W2, DWVDZ, DWVDY
        REAL U1, U2, W_UP, W_MI, W_DN, DUVDY, DUWDZ, DUWDY
        REAL XC, YC, ZC
        REAL UERR, VERR, WERR
        INTEGER I, J, K
        
        !FINISH DV
        DO K = 1, N3
            ZC = (Z(K) + Z(K - 1)) / 2
            DO J = 2, N2
                YC = Y(J - 1)
                DO I = 1, N1
                    XC = (X(I) + X(I - 1)) / 2
                    
                    !D_W^NP_V^N_DZ
                    V1 = (V(I, J, KM(K)) + V(I, J, K)) / 2
                    V2 = (V(I, J, KP(K)) + V(I, J, K)) / 2
                    W1 = (DW(I, J, K) * DY(JM(J)) + DW(I, JM(J), K) * DY(J)) / 2 / H(J)
                    W2 = (DW(I, J, KP(K)) * DY(JM(J)) + DW(I, JM(J), KP(K)) * DY(J)) / 2 / H(J)
                    DWVDZ = (W2 * V2 - W1 * V1) / DZ
                    
                    !D_W^NP_V^N_DY
                    W1 = (DW(I, JM(J), K) + DW(I, JM(J), KP(K))) / 2
                    W2 = (DW(I, J, K) + DW(I, J, KP(K))) / 2
                    V1 = (V(I, J, K) + V(I, JM(J), K)) / 2
                    V2 = (V(I, J, K) + V(I, JP(J), K)) / 2
                    DWVDY = (W2 * V2 - W1 * V1) / H(J)
                    
                    DV(I, J, K) = DV(I, J, K) - DT * (DWVDZ + DWVDY * PHI3(XC, YC, ZC, T + DT)) / 2
                END DO
            END DO
        END DO
        
        !FINISH DU
        DO K = 1, N3
            ZC = (Z(K) + Z(K - 1)) / 2
            DO J = 1, N2
                YC = (Y(J) + Y(J - 1)) / 2
                DO I = 1, N1
                    XC = X(I - 1)
                    
                    !D_U^N_V^N_DY
                    U1 = (U(I, J, K) * DY(JM(J)) + U(I, JM(J), K) * DY(J)) / 2 / H(J)
                    U2 = (U(I, J, K) * DY(JP(J)) + U(I, JP(J), K) * DY(J)) / 2 / H(JP(J))
                    V1 = (DV(IM(I), J, K) + DV(I, J, K)) / 2
                    V2 = (DV(IM(I), JP(J), K) + DV(I, JP(J), K)) / 2
                    DUVDY = (U2 * V2 - U1 * V1) / DY(J)
                    
                    !D_U^N_W^N_DZ
                    U1 = (U(I, J, K) + U(I, J, KM(K))) / 2
                    U2 = (U(I, J, KP(K)) + U(I, J, K)) / 2
                    W1 = (DW(IM(I), J, K) + DW(I, J, K)) / 2
                    W2 = (DW(I, J, KP(K)) + DW(IM(I), J, KP(K))) / 2
                    DUWDZ = (U2 * W2 - U1 * W1) / DZ
                    
                    !D_U^N_W^N_DY
                    W_UP = (DW(IM(I), JP(J), K) + DW(IM(I), JP(J), K) &
                         +  DW(I, JP(J), K) + DW(I, JP(J), KP(K))) / 4
                    W_MI = (DW(I, J, K) + DW(I, J, KP(K)) &
                         +  DW(IM(I), J, KP(K)) + DW(IM(I), J, K)) / 4
                    W_DN = (DW(I, JM(J), K) + DW(I, JM(J), KP(K)) &
                         +  DW(IM(I), JM(J), KP(K)) + DW(IM(I), JM(J), K)) / 4
                    DUWDY = U(I, JP(J), K) * W_UP * DYH(1, J)   &
                          + U(I, J, K) * W_MI * DYH(2, J)       &
                          + U(I, JM(J), K) * W_DN * DYH(3, J)
                    
                    DU(I, J, K) = DU(I, J, K)   &
                                - DT * (1 + PHI2(XC, YC, ZC, T + DT)) * DUVDY / 2   &
                                - DT * (DUWDZ + PHI3(XC, YC, ZC, T + DT) * DUWDY) / 2
                END DO
            END DO
        END DO

        ERR = 0
        
        DO K = 1, N3
            DO J = 1, N2
                DO I = 1, N1
                    IF(ABS(DU(I, J, K)) < EPSILON(UERR)) THEN
                        UERR = ABS(DU(I, J, K) - DUHIST(I, J, K)) / EPSILON(UERR)
                    ELSE
                        UERR = ABS(DU(I, J, K) - DUHIST(I, J, K)) / ABS(DU(I, J, K))
                    END IF
                    IF(ABS(DV(I, J, K)) < EPSILON(VERR)) THEN
                        VERR = ABS(DV(I, J, K) - DVHIST(I, J, K)) / EPSILON(VERR)
                    ELSE
                        VERR = ABS(DV(I, J, K) - DVHIST(I, J, K)) / ABS(DV(I, J, K))
                    END IF
                    IF(ABS(DW(I, J, K)) < EPSILON(WERR)) THEN
                        WERR = ABS(DW(I, J, K) - DWHIST(I, J, K)) / EPSILON(WERR)
                    ELSE
                        WERR = ABS(DW(I, J, K) - DWHIST(I, J, K)) / ABS(DW(I, J, K))
                    END IF
                    
                    ERR = MAX(UERR, VERR, WERR, ERR)
                END DO
            END DO
        END DO
        
    END SUBROUTINE FINISH_VEL
    
    SUBROUTINE FORM_R1()
        IMPLICIT NONE
        REAL VISCOS, CROSS, NONLIN, PRESSG
        REAL DUDX(3), DUDZ(3), DUDY
        REAL DUUDX, DUVDY, DUWDZ, DUUDY, DUWDY
        REAL U1, U2, V1, V2, W1, W2, W_UP, W_MI, W_DN
        REAL XC, YC, ZC
        INTEGER I, J, K
        
        !BIND R1 TO R
        R1 => R
        
        DO K = 1, N3
            ZC = (Z(K) + Z(K - 1)) / 2
            DO J = 1, N2
                YC = (Y(J) + Y(J - 1)) / 2
                DO I = 1, N1
                    XC = X(I - 1)
                    
                    !VISCOS TERM
                    VISCOS = (U(IP(I), J, K) - 2 * U(I, J, K) + U(IM(I), J, K)) / DX / DX   &
                           + (DY2H(1, J) * U(I, JP(J), K) + DY2H(2, J) * U(I, J, K) + DY2H(3, J) * U(I, JM(J), K))  &
                           + (U(I, J, KP(K)) - 2 * U(I, J, K) + U(I, J, KM(K))) / DZ / DZ   &
                           + (  PHI1(XC, YC, ZC, T) * DPHI1DY(XC, YC, ZC, T)    &
                              + PHI2(XC, YC, ZC, T) * DPHI2DY(XC, YC, ZC, T)    &
                              + PHI3(XC, YC, ZC, T) * DPHI3DY(XC, YC, ZC, T)    &
                              + DPHI1DX(XC, YC, ZC, T) + DPHI2DY(XC, YC, ZC, T) &
                              + DPHI3DZ(XC, YC, ZC, T))                         &
                              * (DYH(1, J) * U(I, JP(J), K) + DYH(2, J) * U(I, J, K) + DYH(3, J) * U(I, JM(J), K))  &
                           + (PHI1(XC, YC, ZC, T) ** 2 + PHI2(XC, YC, ZC, T) ** 2 + PHI3(XC, YC, ZC, T) ** 2)       &
                              * (DY2H(1, J) * U(I, JP(J), K) + DY2H(2, J) * U(I, J, K) + DY2H(3, J) * U(I, JM(J), K))
                    
                    !Nth-TIME-STEP CROSS TERM
                    DUDX(1) = (U(IP(I), JP(J), K) - U(IM(I), JP(J), K)) / 2 / DX
                    DUDX(2) = (U(IP(I), J, K) - U(IM(I), J, K)) / 2 / DX
                    DUDX(3) = (U(IP(I), JM(J), K) - U(IM(I), JM(J), K)) / 2 / DX
                    DUDZ(1) = (U(I, JP(J), KP(K)) - U(I, JP(J), KM(K))) / 2 / DZ
                    DUDZ(2) = (U(I, J, KP(K)) - U(I, J, KM(K))) / 2 / DZ
                    DUDZ(3) = (U(I, JM(J), KP(K)) - U(I, JM(J), KM(K))) / 2 / DZ
                    
                    CROSS = (DYH(1, J) * DUDX(1) + DYH(2, J) * DUDX(2) + DYH(3, J) * DUDX(3)) * 2 * PHI1(XC, YC, ZC, T) &
                          + (DY2H(1, J) * U(I, JP(J), K) + DY2H(2, J) * U(I, J, K) + DY2H(3, J) * U(I, JM(J), K)) * 2 * PHI2(XC, YC, ZC, T) &
                          + (DYH(1, J) * DUDZ(1) + DYH(2, J) * DUDZ(2) + DYH(3, J) * DUDZ(3)) * 2 * PHI3(XC, YC, ZC, T)
                    !FORM Nth-TIME-STEP VISCOS TERM
                    VISCOS = (VISCOS + CROSS) / RE * DT
                    
                    !NPth-TIME-STEP CROSS TERM
                    DUDX(1) = (DU(IP(I), JP(J), K) - DU(IM(I), JP(J), K)) / 2 / DX
                    DUDX(2) = (DU(IP(I), J, K) - DU(IM(I), J, K)) / 2 / DX
                    DUDX(3) = (DU(IP(I), JM(J), K) - DU(IM(I), JM(J), K)) / 2 / DX
                    DUDZ(1) = (DU(I, JP(J), KP(K)) - DU(I, JP(J), KM(K))) / 2 / DZ
                    DUDZ(2) = (DU(I, J, KP(K)) - DU(I, J, KM(K))) / 2 / DZ
                    DUDZ(3) = (DU(I, JM(J), KP(K)) - DU(I, JM(J), KM(K))) / 2 / DZ
                    
                    CROSS = (DYH(1, J) * DUDX(1) + DYH(2, J) * DUDX(2) + DYH(3, J) * DUDX(3)) * PHI1(XC, YC, ZC, T + DT) &
                          + (DY2H(1, J) * DU(I, JP(J), K) + DY2H(2, J) * DU(I, J, K) + DY2H(3, J) * DU(I, JM(J), K)) * PHI2(XC, YC, ZC, T + DT) &
                          + (DYH(1, J) * DUDZ(1) + DYH(2, J) * DUDZ(2) + DYH(3, J) * DUDZ(3)) * PHI3(XC, YC, ZC, T + DT)
                    
                    CROSS = CROSS / RE * DT
                    
                    !CURVE COORDINATE TERM
                    DUDY = DYH(1, J) * U(I, JP(J), K) + DYH(2, J) * U(I, J, K) + DYH(3, J) * U(I, JM(J), K)
                    
                    !NONLINEAR TERM
                    !D_U^N_U^N_DX
                    U1 = (U(IM(I), J, K) + U(I, J, K)) / 2
                    U2 = (U(IP(I), J, K) + U(I, J, K)) / 2
                    DUUDX = (U2 * U2 - U1 * U1) / DX
                    
                    !D_U^N_V^N_DY & D_U^N_U^N_DY
                    U1 = (U(I, J, K) * DY(JM(J)) + U(I, JM(J), K) * DY(J)) / 2 / H(J)
                    U2 = (U(I, J, K) * DY(JP(J)) + U(I, JP(J), K) * DY(J)) / 2 / H(JP(J))
                    V1 = (V(IM(I), J, K) + V(I, J, K)) / 2
                    V2 = (V(IM(I), JP(J), K) + V(I, JP(J), K)) / 2
                    DUVDY = (U2 * V2 - U1 * V1) / DY(J)
                    DUUDY = (U2 * U2 - U1 * U1) / DY(J)
                    
                    !D_U^N_W^N_DZ
                    U1 = (U(I, J, K) + U(I, J, KM(K))) / 2
                    U2 = (U(I, J, KP(K)) + U(I, J, K)) / 2
                    W1 = (W(IM(I), J, K) + W(I, J, K)) / 2
                    W2 = (W(I, J, KP(K)) + W(IM(I), J, KP(K))) / 2
                    DUWDZ = (U2 * W2 - U1 * W1) / DZ
                    
                    !D_U^N_W^N_DY
                    W_UP = (W(IM(I), JP(J), K) + W(IM(I), JP(J), K) &
                         +  W(I, JP(J), K) + W(I, JP(J), KP(K))) / 4
                    W_MI = (W(I, J, K) + W(I, J, KP(K)) &
                         +  W(IM(I), J, KP(K)) + W(IM(I), J, K)) / 4
                    W_DN = (W(I, JM(J), K) + W(I, JM(J), KP(K)) &
                         +  W(IM(I), JM(J), KP(K)) + W(IM(I), JM(J), K)) / 4
                    DUWDY = U(I, JP(J), K) * W_UP * DYH(1, J)   &
                          + U(I, J, K) * W_MI * DYH(2, J)       &
                          + U(I, JM(J), K) * W_DN * DYH(3, J)
                    
                    NONLIN = DUUDX + DUVDY + DUWDZ  &
                           + (PHI1(XC, YC, ZC, T) + PHI1(XC, YC, ZC, T + DT)) / 2 * DUUDY   &
                           + (PHI2(XC, YC, ZC, T) + PHI2(XC, YC, ZC, T + DT)) / 2 * DUVDY   &
                           + (PHI3(XC, YC, ZC, T) + PHI3(XC, YC, ZC, T + DT)) / 2 * DUWDY
                    
                    !PRESSURE TERM
                    PRESSG = (P(I, J, K) - P(IM(I), J, K)) / DX + PGX
                    
                    !BOUNDARY TERM IS CALCULATED IN SOLVE ROUTINE
                    
                    !FORM R1 TERM
                    R1(I, J, K) = VISCOS + CROSS - PHIT(XC, YC, ZC, T) * DUDY * DT - NONLIN * DT - PRESSG * DT
                END DO
            END DO
        END DO
    END SUBROUTINE FORM_R1
    
    SUBROUTINE FORM_R2()
        IMPLICIT NONE
        REAL VISCOS, CROSS, NONLIN, PRESSG
        REAL DVDX(3), DVDZ(3), DVDY
        REAL DUVDX, DVVDY, DWVDZ, DUVDY, DWVDY
        REAL U1, U2, V1, V2, W1, W2
        REAL M21U
        REAL XC, YC, ZC
        INTEGER I, J, K
        
        !BIND R2 TO R
        R2 => R
        DO K = 1, N3
            ZC = (Z(K) + Z(K - 1)) / 2
            DO J = 2, N2
                YC = Y(J - 1)
                DO I = 1, N1
                    XC = (X(I) + X(I - 1)) / 2
                    
                    !VISCOS TERM
                    VISCOS = (V(IP(I), J, K) - 2 * V(I, J, K) + V(IM(I), J, K)) / DX / DX   &
                           + (DY2DY(1, J) * V(I, JP(J), K) + DY2DY(2, J) * V(I, J, K) + DY2DY(3, J) * V(I, JM(J), K))   &
                           + (V(I, J, KP(K)) - 2 * V(I, J, K) + V(I, J, KM(K))) / DZ / DZ   &
                           + (  PHI1(XC, YC, ZC, T) * DPHI1DY(XC, YC, ZC, T)    &
                              + PHI2(XC, YC, ZC, T) * DPHI2DY(XC, YC, ZC, T)    &
                              + PHI3(XC, YC, ZC, T) * DPHI3DY(XC, YC, ZC, T)    &
                              + DPHI1DX(XC, YC, ZC, T) + DPHI2DY(XC, YC, ZC, T) &
                              + DPHI3DZ(XC, YC, ZC, T))                         &
                              * (DYDY(1, J) * V(I, JP(J), K) + DYDY(2, J) * V(I, J, K) + DYDY(3, J) * V(I, JM(J), K))   &
                           + (PHI1(XC, YC, ZC, T) ** 2 + PHI2(XC, YC, ZC, T) ** 2 + PHI3(XC, YC, ZC, T) ** 2)           &
                              * (DY2DY(1, J) * V(I, JP(J), K) + DY2DY(2, J) * V(I, J, K) + DY2DY(3, J) * V(I, JM(J), K))
                    
                    !Nth-TIME-STEP CROSS TERM
                    DVDX(1) = (V(IP(I), JP(J), K) - V(IM(I), JP(J), K)) / 2 / DX
                    DVDX(2) = (V(IP(I), J, K) - V(IM(I), J, K)) / 2 / DX
                    DVDX(3) = (V(IP(I), JM(J), K) - V(IM(I), JM(J), K)) / 2 / DX
                    DVDZ(1) = (V(I, JP(J), KP(K)) - V(I, JP(J), KM(K))) / 2 / DZ
                    DVDZ(2) = (V(I, J, KP(K)) - V(I, J, KM(K))) / 2 / DZ
                    DVDZ(3) = (V(I, JM(J), KP(K)) - V(I, JM(J), KM(K))) / 2 / DZ
                    
                    CROSS = (DYDY(1, J) * DVDX(1) + DYDY(2, J) * DVDX(2) + DYDY(3, J) * DVDX(3)) * 2 * PHI1(XC, YC, ZC, T)  &
                          + (DY2DY(1, J) * V(I, JP(J), K) + DY2DY(2, J) * V(I, J, K) + DY2DY(3, J) * V(I, JM(J), K)) * 2 * PHI2(XC, YC, ZC, T)  &
                          + (DYDY(1, J) * DVDZ(1) + DYDY(2, J) * DVDZ(2) + DYDY(3, J) * DVDZ(3)) * 2 * PHI3(XC, YC, ZC, T)
                    
                    !FORM Nth-TIME-STEP VISCOS TERM
                    VISCOS = (VISCOS + CROSS) / RE * DT
                    
                    !NPth-TIME-STEP CROSS TERM
                    DVDX(1) = (DV(IP(I), JP(J), K) - DV(IM(I), JP(J), K)) / 2 / DX
                    DVDX(2) = (DV(IP(I), J, K) - DV(IM(I), J, K)) / 2 / DX
                    DVDX(3) = (DV(IP(I), JM(J), K) - DV(IM(I), JM(J), K)) / 2 / DX
                    DVDZ(1) = (DV(I, JP(J), KP(K)) - DV(I, JP(J), KM(K))) / 2 / DZ
                    DVDZ(2) = (DV(I, J, KP(K)) - DV(I, J, KM(K))) / 2 / DZ
                    DVDZ(3) = (DV(I, JM(J), KP(K)) - DV(I, JM(J), KM(K))) / 2 / DZ
                    
                    CROSS = (DYDY(1, J) * DVDX(1) + DYDY(2, J) * DVDX(2) + DYDY(3, J) * DVDX(3)) * PHI1(XC, YC, ZC, T + DT)  &
                          + (DY2DY(1, J) * DV(I, JP(J), K) + DY2DY(2, J) * DV(I, J, K) + DY2DY(3, J) * DV(I, JM(J), K)) * PHI2(XC, YC, ZC, T + DT)  &
                          + (DYDY(1, J) * DVDZ(1) + DYDY(2, J) * DVDZ(2) + DYDY(3, J) * DVDZ(3)) * PHI3(XC, YC, ZC, T + DT)
                    
                    CROSS = CROSS / RE * DT
                    
                    !CURVE COORDINATE TERM
                    DVDY = DYDY(1, J) * V(I, JP(J), K) + DYDY(2, J) * V(I, J, K) + DYDY(3, J) * V(I, JM(J), K)
                    
                    !NONLINEAR TERM
                    !D_U^N_V^N_DX
                    U1 = (U(I, JM(J), K) * DY(J) + U(I, J, K) * DY(JM(J))) / 2 / H(J)
                    U2 = (U(IP(I), JM(J), K) * DY(J) + U(IP(I), J, K) * DY(JM(J))) / 2 / H(J)
                    V1 = (V(I, J, K) + V(IM(I), J, K)) / 2
                    V2 = (V(I, J, K) + V(IP(I), J, K)) / 2
                    DUVDX = (U2 * V2 - U1 * V1) / DX
                    
                    !D_V^N_V^N_DY & D_U^N_V^N_DY
                    U1 = (U(I, JM(J), K) + U(IP(I), JM(J), K)) / 2
                    U2 = (U(I, J, K) + U(IP(I), J, K)) / 2
                    V1 = (V(I, JM(J), K) + V(I, J, K)) / 2
                    V2 = (V(I, JP(J), K) + V(I, J, K)) / 2
                    DUVDY = (U2 * V2 - U1 * V1) / H(J)
                    DVVDY = (V2 * V2 - V1 * V1) / H(J)
                    
                    !D_W^N_V^N_DZ
                    V1 = (V(I, J, KM(K)) + V(I, J, K)) / 2
                    V2 = (V(I, J, KP(K)) + V(I, J, K)) / 2
                    W1 = (W(I, J, K) * DY(JM(J)) + W(I, JM(J), K) * DY(J)) / 2 / H(J)
                    W2 = (W(I, J, KP(K)) * DY(JM(J)) + W(I, JM(J), KP(K)) * DY(J)) / 2 / H(J)
                    DWVDZ = (W2 * V2 - W1 * V1) / DZ
                    
                    !D_W^N_V^N_DY
                    W1 = (W(I, JM(J), K) + W(I, JM(J), KP(K))) / 2
                    W2 = (W(I, J, K) + W(I, J, KP(K))) / 2
                    V1 = (V(I, J, K) + V(I, JM(J), K)) / 2
                    V2 = (V(I, J, K) + V(I, JP(J), K)) / 2
                    DWVDY = (W2 * V2 - W1 * V1) / H(J)
                    
                    NONLIN = DUVDX + DVVDY + DWVDZ  &
                           + (PHI1(XC, YC, ZC, T) + PHI1(XC, YC, ZC, T + DT)) / 2 * DUVDY   &
                           + (PHI2(XC, YC, ZC, T) + PHI2(XC, YC, ZC, T + DT)) / 2 * DVVDY   &
                           + (PHI3(XC, YC, ZC, T) + PHI3(XC, YC, ZC, T + DT)) / 2 * DWVDY
                    
                    !PRESSURE TERM
                    PRESSG = (P(I, J, K) - P(I, JM(J), K)) / H(J) + PGY
                    
                    !M21 TERM
                    
                    !D_V^N_U^NP_DX
                    U1 = (DY(J) * DU(I, JM(J), K) + DY(JM(J)) * DU(I, J, K)) / 2 / H(J)
                    U2 = (DY(J) * DU(IP(I), JM(J), K) + DY(JM(J)) * DU(IP(I), J, K)) / 2 / H(J)
                    V1 = (V(I, J, K) + V(IM(I), J, K)) / 2
                    V2 = (V(IP(I), J, K) + V(I, J, K)) / 2
                    
                    DUVDX = (U2 * V2 - U1 * V1) / DX
                    
                    !D_V^N_U^NP_DX
                    U1 = (DU(I, JM(J), K) + DU(IP(I), JM(J), K)) / 2
                    U2 = (DU(I, J, K) + DU(IP(I), J, K)) / 2
                    V1 = (V(I, JM(J), K) + V(I, J, K)) / 2
                    V2 = (V(I, JP(J), K) + V(I, J, K)) / 2
                    
                    DUVDY = (U2 * V2 - U1 * V1) / H(J)
                    
                    M21U = (DUVDX + PHI1(XC, YC, ZC, T + DT) * DUVDY) / 2
                    
                    !FORM R2 TERM
                    R2(I, J, K) = VISCOS + CROSS - PHIT(XC, YC, ZC, T) * DVDY * DT &
                                - NONLIN * DT - PRESSG * DT - M21U * DT
                END DO
            END DO
        END DO
    END SUBROUTINE FORM_R2
    
    SUBROUTINE FORM_R3
        IMPLICIT NONE
        REAL VISCOS, CROSS, NONLIN, PRESSG
        REAL DWDX(3), DWDZ(3), DWDY
        REAL DUWDX, DVWDY, DWWDZ, DUWDY, DWWDY
        REAL U1, U2, V1, V2, W1, W2, U_UP, U_MI, U_DN
        REAL M31U, M32V
        REAL XC, YC, ZC
        INTEGER I, J, K
        
        !BIND R3 TO R
        R3 => R
        DO K = 1, N3
            ZC = Z(K - 1)
            DO J = 1, N2
                YC = (Y(J) + Y(J - 1)) / 2
                DO I = 1, N1
                    XC = (X(I) + X(I - 1)) / 2
                    
                    !VISCOS TERM
                    VISCOS = (W(IP(I), J, K) - 2 * W(I, J, K) + W(IM(I), J, K)) / DX / DX   &
                           + (DY2H(1, J) * W(I, JP(J), K) + DY2H(2, J) * W(I, J, K) + DY2H(3, J) * W(I, JM(J), K))  &
                           + (W(I, J, KP(K)) - 2 * W(I, J, K) + W(I, J, KM(K))) / DZ / DZ   &
                           + (  PHI1(XC, YC, ZC, T) * DPHI1DY(XC, YC, ZC, T)    &
                              + PHI2(XC, YC, ZC, T) * DPHI2DY(XC, YC, ZC, T)    &
                              + PHI3(XC, YC, ZC, T) * DPHI3DY(XC, YC, ZC, T)    &
                              + DPHI1DX(XC, YC, ZC, T) + DPHI2DY(XC, YC, ZC, T) &
                              + DPHI3DZ(XC, YC, ZC, T))                         &
                              * (DYH(1, J) * W(I, JP(J), K) + DYH(2, J) * W(I, J, K) + DYH(3, J) * W(I, JM(J), K))  &
                           + (PHI1(XC, YC, ZC, T) ** 2 + PHI2(XC, YC, ZC, T) ** 2 + PHI3(XC, YC, ZC, T) ** 2)       &
                              * (DY2H(1, J) * W(I, JP(J), K) + DY2H(2, J) * W(I, J, K) + DY2H(3, J) * W(I, JM(J), K))
                    
                    !Nth-TIME-STEP CROSS TERM
                    DWDX(1) = (W(IP(I), JP(J), K) - W(IM(I), JP(J), K)) / 2 / DX
                    DWDX(2) = (W(IP(I), J, K) - W(IM(I), J, K)) / 2 / DX
                    DWDX(3) = (W(IP(I), JM(J), K) - W(IM(I), JM(J), K)) / 2 / DX
                    DWDZ(1) = (W(I, JP(J), KP(K)) - W(I, JP(J), KM(K))) / 2 / DZ
                    DWDZ(2) = (W(I, J, KP(K)) - W(I, J, KM(K))) / 2 / DZ
                    DWDZ(3) = (W(I, JM(J), KP(K)) - W(I, JM(J), KP(K))) / 2 / DZ
                    
                    CROSS = (DYH(1, J) * DWDX(1) + DYH(2, J) * DWDX(2) + DYH(3, J) * DWDX(3)) * 2 * PHI1(XC, YC, ZC, T) &
                          + (DY2H(1, J) * W(I, JP(J), K) + DY2H(2, J) * W(I, J, K) + DY2H(3, J) * W(I, JM(J), K)) * 2 * PHI2(XC, YC, ZC, T) &
                          + (DYH(1, J) * DWDZ(1) + DYH(2, J) * DWDZ(2) + DYH(3, J) * DWDZ(3)) * 2 * PHI3(XC, YC, ZC, T)
                    
                    !FORM Nth-TIME-STEP VISCOS TERM
                    VISCOS = (VISCOS + CROSS) / RE * DT
                    
                    !NPth-TIME-STEP CROSS TERM
                    DWDX(1) = (DW(IP(I), JP(J), K) - DW(IM(I), JP(J), K)) / 2 / DX
                    DWDX(2) = (DW(IP(I), J, K) - DW(IM(I), J, K)) / 2 / DX
                    DWDX(3) = (DW(IP(I), JM(J), K) - DW(IM(I), JM(J), K)) / 2 / DX
                    DWDZ(1) = (DW(I, JP(J), KP(K)) - DW(I, JP(J), KM(K))) / 2 / DZ
                    DWDZ(2) = (DW(I, J, KP(K)) - DW(I, J, KM(K))) / 2 / DZ
                    DWDZ(3) = (DW(I, JM(J), KP(K)) - DW(I, JM(J), KM(K))) / 2 / DZ
                    
                    CROSS = (DYH(1, J) * DWDX(1) + DYH(2, J) * DWDX(2) + DYH(3, J) * DWDX(3)) * PHI1(XC, YC, ZC, T + DT) &
                          + (DY2H(1, J) * DW(I, JP(J), K) + DY2H(2, J) * DW(I, J, K) + DY2H(3, J) * DW(I, JM(J), K)) * PHI2(XC, YC, ZC, T + DT) &
                          + (DYH(1, J) * DWDZ(1) + DYH(2, J) * DWDZ(2) + DYH(3, J) * DWDZ(3)) * PHI3(XC, YC, ZC, T + DT)
                    
                    CROSS = CROSS / RE * DT
                    
                    !CURVE COORDINATE TERM
                    DWDY = DYH(1, J) * W(I, JP(J), K) + DYH(2, J) * W(I, J, K) + DYH(3, J) * W(I, JM(J), K)
                    
                    !NONLINEAR TERM
                    !D_U^N_W^N_DX
                    U1 = (U(I, J, KP(K)) + U(I, J, K)) / 2
                    U2 = (U(IP(I), J, KP(K)) + U(IP(I), J, K)) / 2
                    W1 = (W(IM(I), J, K) + W(I, J, K)) / 2
                    W2 = (W(IP(I), J, K) + W(I, J, K)) / 2
                    DUWDX = (U2 * W2 - U1 * W1) / DX
                    
                    !D_V^N_W^N_DY & D_W^N_W^N_DY
                    V1 = (V(I, J, K) + V(I, J, KM(K))) / 2
                    V2 = (V(I, JP(J), K) + V(I, JP(J), KM(K))) / 2
                    W1 = (W(I, J, K) * DY(JM(J)) + W(I, JM(J), K) * DY(J)) / 2 / H(J)
                    W2 = (W(I, JP(J), K) * DY(J) + W(I, J, K) * DY(JP(J))) / 2 / H(JP(J))
                    DVWDY = (V2 * W2 - V1 * W1) / DY(J)
                    DWWDY = (W2 * W2 - W1 * W1) / DY(J)
                    
                    !D_W^N_W^N_DZ
                    W1 = (W(I, J, KM(K)) + W(I, J, K)) / 2
                    W2 = (W(I, J, KP(K)) + W(I, J, K)) / 2
                    DWWDZ = (W2 * W2 - W1 * W1) / DZ
                    
                    !D_U^N_W^N_DY
                    U_UP = (U(I, JP(J), K) + U(IP(I), JP(J), K) &
                         +  U(I, JP(J), KM(K)) + U(IP(I), JP(J), KM(K))) / 4
                    U_MI = (U(I, J, K) + U(IP(I), J, K) &
                         +  U(I, J, KM(K)) + U(IP(I), J, KM(K))) / 4
                    U_DN = (U(I, JM(J), K) + U(IP(I), JM(J), K) &
                         +  U(I, JM(J), KM(K)) + U(IP(I), JM(J), KM(K))) / 4
                    DUWDY = U_UP * W(I, JP(J), K) * DYH(1, J)   &
                          + U_MI * W(I, J, K) * DYH(2, J)       &
                          + U_DN * W(I, JM(J), K) * DYH(3, J)
                    
                    NONLIN = DUWDX + DVWDY + DWWDZ  &
                           + (PHI1(XC, YC, ZC, T) + PHI1(XC, YC, ZC, T + DT)) / 2 * DUWDY   &
                           + (PHI2(XC, YC, ZC, T) + PHI2(XC, YC, ZC, T + DT)) / 2 * DVWDY   &
                           + (PHI3(XC, YC, ZC, T) + PHI3(XC, YC, ZC, T + DT)) / 2 * DWWDY
                    
                    !PRESSURE TERM
                    PRESSG = (P(I, J, K) - P(I, J, KM(K))) / DZ + PGZ
                    
                    !M31 TERM
                    
                    !D_W^N_U^NP_DX
                    U1 = (DU(I, J, KP(K)) + DU(I, J, K)) / 2
                    U2 = (DU(IP(I), J, KP(K)) + DU(IP(I), J, K)) / 2
                    W1 = (W(IM(I), J, K) + W(I, J, K)) / 2
                    W2 = (W(I, J, K) + W(IP(I), J, K)) / 2
                    
                    DUWDX = (U2 * W2 - U1 * W1) / DX
                    
                    !D_W^N_U^NP_DY
                    U_UP = (DU(I, JP(J), K) + DU(IP(I), JP(J), K) &
                         +  DU(I, JP(J), KM(K)) + DU(IP(I), JP(J), KM(K))) / 4
                    U_MI = (DU(I, J, K) + DU(IP(I), J, K) &
                         +  DU(I, J, KM(K)) + DU(IP(I), J, KM(K))) / 4
                    U_DN = (DU(I, JM(J), K) + DU(IP(I), JM(J), K) &
                         +  DU(I, JM(J), KM(K)) + DU(IP(I), JM(J), KM(K))) / 4
                    DUWDY = U_UP * W(I, JP(J), K) * DYH(1, J)   &
                          + U_MI * W(I, J, K) * DYH(2, J)       &
                          + U_DN * W(I, JM(J), K) * DYH(3, J)
                    
                    M31U = (DUWDX + PHI1(XC, YC, ZC, T + DT) * DUWDY) / 2
                    
                    !M32 TERM
                    
                    !D_W^N_V^NP_DY
                    V1 = (DV(I, J, K) + DV(I, J, KM(K))) / 2
                    V2 = (DV(I, JP(J), K) + DV(I, JP(J), KM(K))) / 2
                    W1 = (W(I, J, K) * DY(JM(J)) + W(I, JM(J), K) * DY(J)) / 2 / H(J)
                    W2 = (W(I, JP(J), K) * DY(J) + W(I, J, K) * DY(JP(J))) / 2 / H(JP(J))
                    
                    DVWDY = (V2 * W2 - V1 * W1) / H(J)
                    
                    M32V = (1 + PHI2(XC, YC, ZC, T + DT)) * DVWDY / 2
                    
                    !FORM R3 TERM
                    R3(I, J, K) = VISCOS + CROSS - PHIT(XC, YC, ZC, T) * DWDY * DT     &
                                - NONLIN * DT - PRESSG * DT - M31U * DT - M32V * DT
                END DO
            END DO
        END DO
    END SUBROUTINE FORM_R3

    SUBROUTINE SOLVE_UH()
        IMPLICIT NONE
        
        INTEGER I, J, K
        REAL XC, YC, ZC
        REAL U1, U2, V1, V2, W1, W2, PHI, W_UP, W_MI, W_DN
        REAL VISNM, VISNC, VISNP, VISFAC
        
        CALL ALLOC_FAC(MAX(N1, N2, N3))
        
        !SOLVE IN Y DIRECTION
        DO K = 1, N3
            ZC = (Z(K) + Z(K - 1)) / 2
            DO I = 1, N1
                XC = X(I - 1)
                DO J = 1, N2
                    YC = (Y(J) + Y(J - 1)) / 2
                    
                    !PHI * D_V^N_U^NP_DY
                    PHI = 1 + PHI2(XC, YC, ZC, T)
                    V1 = (V(IM(I), J, K) + V(I, J, K)) / 2
                    V2 = (V(IM(I), JP(J), K) + V(I, JP(J), K)) / 2
                    NPFAC(J) = PHI * V2 / 2 / H(JP(J))
                    NCFAC(J) = PHI * (V2 * DY(JP(J)) / 2 / H(JP(J)) - V1 * DY(JM(J)) / 2 / H(J)) / DY(J)
                    NMFAC(J) = PHI * -V1 / 2 / H(J)
                    
                    !PHI * D_U^N_U^NP_DY
                    PHI = PHI1(XC, YC, ZC, T) + PHI1(XC, YC, ZC, T + DT)
                    U1 = (U(I, J, K) * DY(JM(J)) + U(I, JM(J), K) * DY(J)) / 2 / H(J)
                    U2 = (U(I, J, K) * DY(JP(J)) + U(I, JP(J), K) * DY(J)) / 2 / H(JP(J))
                    NPFAC(J) = NPFAC(J) + PHI * U2 / 2 / H(JP(J))
                    NCFAC(J) = NCFAC(J) + PHI * (U2 * DY(JP(J)) / 2 / H(JP(J)) - U1 * DY(JM(J)) / 2 / H(J)) / DY(J)
                    NMFAC(J) = NMFAC(J) + PHI * -U1 / 2 / H(J)
                    
                    !PHI * D_W^N_U^NP_DY
                    PHI = PHI3(XC, YC, ZC, T)
                    W_UP = (W(IM(I), JP(J), K) + W(IM(I), JP(J), K) &
                         +  W(I, JP(J), K) + W(I, JP(J), KP(K))) / 4
                    W_MI = (W(I, J, K) + W(I, J, KP(K)) &
                         +  W(IM(I), J, KP(K)) + W(IM(I), J, K)) / 4
                    W_DN = (W(I, JM(J), K) + W(I, JM(J), KP(K)) &
                         +  W(IM(I), JM(J), KP(K)) + W(IM(I), JM(J), K)) / 4
                    NPFAC(J) = NPFAC(J) + PHI * W_UP * DYH(1, J)
                    NCFAC(J) = NCFAC(J) + PHI * W_MI * DYH(2, J)
                    NMFAC(J) = NMFAC(J) + PHI * W_DN * DYH(3, J)
                    
                    !VISCOS TERM
                    !(PHI_I * DPHIDY + DPHIDXI) * D_DY
                    VISFAC = PHI1(XC, YC, ZC, T + DT) * DPHI1DY(XC, YC, ZC, T + DT)   &
                           + PHI2(XC, YC, ZC, T + DT) * DPHI2DY(XC, YC, ZC, T + DT)   &
                           + PHI3(XC, YC, ZC, T + DT) * DPHI3DY(XC, YC, ZC, T + DT)   &
                           + DPHI1DX(XC, YC, ZC, T + DT) + DPHI2DY(XC, YC, ZC, T + DT)&
                           + DPHI3DZ(XC, YC, ZC, T + DT)
                    VISNP = VISFAC * DYH(1, J)
                    VISNC = VISFAC * DYH(2, J)
                    VISNM = VISFAC * DYH(3, J)
                    
                    !(1 + PHI_I ** 2) * D2_DY2
                    VISFAC = PHI1(XC, YC, ZC, T + DT) ** 2 + PHI2(XC, YC, ZC, T + DT) ** 2  &
                           + PHI3(XC, YC, ZC, T + DT) ** 2 + 1
                    VISNP = VISNP + VISFAC * DY2H(1, J)
                    VISNC = VISNC + VISFAC * DY2H(2, J)
                    VISNM = VISNM + VISFAC * DY2H(3, J)
                    
                    NPFAC(J) = NPFAC(J) - VISNP / RE
                    NCFAC(J) = NCFAC(J) - VISNC / RE
                    NMFAC(J) = NMFAC(J) - VISNM / RE
                END DO
                NPFAC = NPFAC / 2 * DT
                NCFAC = NCFAC / 2 * DT + 1
                NMFAC = NMFAC / 2 * DT
                
                !BOUNDARY TERM CORRECT
                R1(I, 1, K) = R1(I, 1, K) - NMFAC(1) * DU(I, 0, K)
                R1(I, N2, K) = R1(I, N2, K) - NPFAC(N2) * DU(I, N2+1, K)
                
                CALL TDMA(NMFAC, NCFAC, NPFAC, DU(I, 1 : N2, K), R1(I, 1 : N2, K))
            END DO
        END DO
        
        NPFAC = 0
        NCFAC = 0
        NMFAC = 0
        
        !SOLVE IN X DIRECTION
        DO K = 1, N3
            DO J = 1, N2
                DO I = 1, N1
                    
                    !TIME ADVANCE TERM
                    !NCFAC(I) = 1
                    
                    !D_U^N_U^NP_DX
                    U1 = (U(IM(I), J, K) + U(I, J, K)) / 2
                    U2 = (U(IP(I), J, K) + U(I, J, K)) / 2
                    NPFAC(I) = U2 / 2 / DX * DT
                    NCFAC(I) = (U2 - U1) / 2 / DX * DT
                    NMFAC(I) = -U1 / 2 / DX * DT
                    
                    !VISCOS TERM
                    NPFAC(I) = NPFAC(I) - 1 / DX / DX / 2 / RE * DT
                    NCFAC(I) = NCFAC(I) + 1 / DX / DX / RE * DT
                    NMFAC(I) = NMFAC(I) - 1 / DX / DX / 2 / RE * DT
                END DO
                NCFAC(1:N1) = NCFAC(1:N1) + 1
                CALL CTDMA(NMFAC, NCFAC, NPFAC, DU(1:N1, J, K), DU(1:N1, J, K))
            END DO
        END DO
        
        NCFAC = 0
        NPFAC = 0
        NMFAC = 0
        
        !SOLVE IN Z DIRECTION
        DO J = 1, N2
            DO I = 1, N1
                DO K = 1, N3
                    
                    !D_W^N_U^NP_DZ
                    W1 = (W(IM(I), J, K) + W(I, J, K)) / 2
                    W2 = (W(I, J, KP(K)) + W(IM(I), J, KP(K))) / 2
                    NPFAC(K) = W2 / 2 / DZ
                    NCFAC(K) = (W2 - W1) / 2 / DZ
                    NMFAC(K) = -W1 / 2 / DZ
                    
                    !VISCOS TERM
                    NPFAC(K) = NPFAC(K) - 1 / DZ / DZ / RE
                    NCFAC(K) = NCFAC(K) + 2 / DZ / DZ / RE
                    NMFAC(K) = NMFAC(K) - 1 / DZ / DZ / RE
                END DO
                NPFAC = NPFAC / 2 * DT
                NCFAC = NCFAC / 2 * DT + 1
                NMFAC = NMFAC / 2 * DT
                CALL CTDMA(NMFAC, NCFAC, NPFAC, DU(I, J, 1:N3), DU(I, J, 1:N3))
            END DO
        END DO
        
    END SUBROUTINE SOLVE_UH
    
    SUBROUTINE SOLVE_VH()
        IMPLICIT NONE
        
        INTEGER I, J, K
        REAL XC, YC, ZC
        REAL U1, U2, V1, V2, W1, W2, PHI
        REAL VISNM, VISNC, VISNP, VISFAC
        
        CALL ALLOC_FAC(MAX(N1, N2, N3))
        
        !SOLVE IN Y DIRECTION
        DO K = 1, N3
            ZC = (Z(K) + Z(K - 1)) / 2
            DO I = 1, N1
                XC = (X(I) + X(I - 1)) / 2
                DO J = 2, N2
                    YC = Y(J - 1)
                    
                    !D_V^N_V^NP_DY
                    PHI = (PHI2(XC, YC, ZC, T) + PHI2(XC, YC, ZC, T + DT)) / 2 + 1
                    V1 = (V(I, JM(J), K) + V(I, J, K)) / 2
                    V2 = (V(I, JP(J), K) + V(I, J, K)) / 2
                    NPFAC(J) = PHI * V2 / 2 / H(J)
                    NCFAC(J) = PHI * (V2 - V1) / 2 / H(J)
                    NMFAC(J) = PHI * -V1 / 2 / H(J)
                    
                    !PHI * D_U^N_V^NP_DY
                    PHI = PHI1(XC, YC, ZC, T) / 2
                    U1 = (U(I, JM(J), K) + U(IP(I), JM(J), K)) / 2
                    U2 = (U(I, J, K) + U(IP(I), J, K)) / 2
                    NPFAC(J) = NPFAC(J) + PHI * U2 / 2 / H(J)
                    NCFAC(J) = NCFAC(J) + PHI * (U2 - U2) / 2 / H(J)
                    NMFAC(J) = NMFAC(J) + PHI * -U1 / 2 / H(J)
                    
                    !PHI * D_W^N_V^NP_DY
                    PHI = PHI3(XC, YC, ZC, T) / 2
                    W1 = (W(I, JM(J), K) + W(I, JM(J), KP(K))) / 2
                    W2 = (W(I, J, K) + W(I, J, KP(K))) / 2
                    NPFAC(J) = NPFAC(J) + PHI * W2 / 2 / H(J)
                    NCFAC(J) = NCFAC(J) + PHI * (W2 - W1) / 2 / H(J)
                    NMFAC(J) = NMFAC(J) + PHI * -W1 / 2 / H(J)
                    
                    !VISCOS TERM
                    !(PHI_I * DPHIDY + DPHIDXI) * D_DY
                    VISFAC = PHI1(XC, YC, ZC, T + DT) * DPHI1DY(XC, YC, ZC, T + DT)   &
                           + PHI2(XC, YC, ZC, T + DT) * DPHI2DY(XC, YC, ZC, T + DT)   &
                           + PHI3(XC, YC, ZC, T + DT) * DPHI3DY(XC, YC, ZC, T + DT)   &
                           + DPHI1DX(XC, YC, ZC, T + DT) + DPHI2DY(XC, YC, ZC, T + DT)&
                           + DPHI3DZ(XC, YC, ZC, T + DT)
                    VISFAC = VISFAC / 2 / RE
                    VISNP = VISFAC * DYDY(1, J)
                    VISNC = VISFAC * DYDY(2, J)
                    VISNM = VISFAC * DYDY(3, J)
                    
                    !(1 + PHI_I ** 2) * D2_DY2
                    VISFAC = PHI1(XC, YC, ZC, T + DT) ** 2 + PHI2(XC, YC, ZC, T + DT) ** 2  &
                           + PHI3(XC, YC, ZC, T + DT) ** 2 + 1
                    VISFAC = VISFAC / 2 / RE
                    VISNP = VISNP + VISFAC * DY2DY(1, J)
                    VISNC = VISNC + VISFAC * DY2DY(2, J)
                    VISNM = VISNM + VISFAC * DY2DY(3, J)
                    
                    NPFAC(J) = NPFAC(J) - VISNP
                    NCFAC(J) = NCFAC(J) - VISNC
                    NMFAC(J) = NMFAC(J) - VISNM
                END DO
                NPFAC = NPFAC * DT
                NCFAC = NCFAC * DT + 1
                NMFAC = NMFAC * DT
                
                !BOUNDARY TERM CORRECT
                R2(I, 2, K) = R2(I, 2, K) - NMFAC(2) * DV(I, 1, K)
                R2(I, N2, K) = R2(I, N2, K) - NPFAC(N2) * DV(I, N2+1, K)
                
                CALL TDMA(NMFAC(2:N2), NCFAC(2:N2), NPFAC(2:N2), DV(I, 2:N2, K), R2(I, 2:N2, K))
            END DO
        END DO
        
        NPFAC = 0
        NCFAC = 0
        NMFAC = 0
        
        !SOLVE IN X DIRECTION
        DO K = 1, N3
            DO J = 2, N2
                DO I = 1, N1
                    
                    !D_U^N_V^NP_DX
                    U1 = (U(I, JM(J), K) * DY(J) + U(I, J, K) * DY(JM(J))) / 2 / H(J)
                    U2 = (U(IP(I), JM(J), K) * DY(J) + U(IP(I), J, K) * DY(JM(J))) / 2 / H(J)
                    NPFAC(I) = U2 / 2 / DX
                    NCFAC(I) = (U2 - U1) / 2 / DX
                    NMFAC(I) = -U1 / 2 / DX
                    
                    !VISCOS TERM
                    NPFAC(I) = NPFAC(I) - 1 / DX / DX / RE
                    NCFAC(I) = NCFAC(I) + 2 / DX / DX / RE
                    NMFAC(I) = NMFAC(I) - 1 / DX / DX / RE
                END DO
                NPFAC = NPFAC / 2 * DT
                NCFAC = NCFAC / 2 * DT + 1
                NMFAC = NMFAC / 2 * DT
                CALL CTDMA(NMFAC, NCFAC, NPFAC, DV(1:N1, J, K), DV(1:N1, J, K))
            END DO
        END DO
        
        NCFAC = 0
        NPFAC = 0
        NMFAC = 0
        
        !SOLVE IN Z DIRECTION
        DO J = 2, N2
            DO I = 1, N1
                DO K = 1, N3
                    
                    !D_W^N_V^NP_DZ
                    W1 = (W(I, J, K) * DY(JM(J)) + W(I, JM(J), K) * DY(J)) / 2 / H(J)
                    W2 = (W(I, J, KP(K)) * DY(JM(J)) + W(I, JM(J), KP(K)) * DY(J)) / 2 / H(J)
                    NPFAC(K) = W2 / 2 / DZ
                    NCFAC(K) = (W2 - W1) / 2 / DZ
                    NMFAC(K) = -W1 / 2 / DZ
                    
                    !VISCOS TERM
                    NPFAC(K) = NPFAC(K) - 1 / DZ / DZ / RE
                    NCFAC(K) = NCFAC(K) + 2 / DZ / DZ / RE
                    NMFAC(K) = NMFAC(K) - 1 / DZ / DZ / RE
                END DO
                NPFAC = NPFAC / 2 * DT
                NCFAC = NCFAC / 2 * DT + 1
                NMFAC = NMFAC / 2 * DT
                CALL CTDMA(NMFAC, NCFAC, NPFAC, DV(I, J, 1:N3), DV(I, J, 1:N3))
            END DO
        END DO
    END SUBROUTINE SOLVE_VH
    
    SUBROUTINE SOLVE_WH()
        IMPLICIT NONE
        
        INTEGER I, J, K
        REAL XC, YC, ZC
        REAL U1, U2, V1, V2, W1, W2, PHI, U_UP, U_MI, U_DN
        REAL VISNM, VISNC, VISNP, VISFAC
        
        CALL ALLOC_FAC(MAX(N1, N2, N3))
        
        !SOLVE IN Y DIRECTION
        DO K = 1, N3
            ZC = Z(K - 1)
            DO I = 1, N1
                XC = (X(I) + X(I - 1)) / 2
                DO J = 1, N2
                    YC = (Y(J) + Y(J - 1)) / 2
                    
                    !PHI * D_V^N_W^NP_DY
                    PHI = 1 + PHI2(XC, YC, ZC, T)
                    V1 = (V(I, J, K) + V(I, J, KM(K))) / 2
                    V2 = (V(I, JP(J), K) + V(I, JP(J), KM(K))) / 2
                    NPFAC(J) = PHI * V2 / 2 / H(JP(J))
                    NCFAC(J) = PHI * (V2 * DY(JP(J)) / H(JP(J)) - V1 * DY(JM(J)) / H(J)) / 2 / DY(J)
                    NMFAC(J) = PHI * -V1 / 2 / H(J)
                    
                    !PHI * D_W^N_W^NP_DY
                    PHI = PHI3(XC, YC, ZC, T) + PHI3(XC, YC, ZC, T + DT)
                    W1 = (W(I, J, K) * DY(JM(J)) + W(I, JM(J), K) * DY(J)) / 2 / H(J)
                    W2 = (W(I, JP(J), K) * DY(J) + W(I, J, K) * DY(JP(J))) / 2 / H(JP(J))
                    NPFAC(J) = NPFAC(J) + PHI * W2 / 2 / H(JP(J))
                    NCFAC(J) = NCFAC(J) + PHI * (W2 * DY(JP(J)) / H(JP(J)) - W1 * DY(JM(J)) / H(J)) / 2 / DY(J)
                    NMFAC(J) = NMFAC(J) + PHI * -W1 / 2 / H(J)
                    
                    !PHI * D_U^N_W^NP_DY
                    PHI = PHI1(XC, YC, ZC, T)
                    U_UP = (U(I, JP(J), K) + U(IP(I), JP(J), K) &
                         +  U(I, JP(J), KM(K)) + U(IP(I), JP(J), KM(K))) / 4
                    U_MI = (U(I, J, K) + U(IP(I), J, K) &
                         +  U(I, J, KM(K)) + U(IP(I), J, KM(K))) / 4
                    U_DN = (U(I, JM(J), K) + U(IP(I), JM(J), K) &
                         +  U(I, JM(J), KM(K)) + U(IP(I), JM(J), KM(K))) / 4
                    NPFAC(J) = NPFAC(J) + PHI * U_UP * DYH(1, J)
                    NCFAC(J) = NCFAC(J) + PHI * U_MI * DYH(2, J)
                    NMFAC(J) = NMFAC(J) + PHI * U_DN * DYH(3, J)
                    
                    !VISCOS TERM
                    !(PHI_I * DPHIDY + DPHIDXI) * D_DY
                    VISFAC = PHI1(XC, YC, ZC, T + DT) * DPHI1DY(XC, YC, ZC, T + DT)   &
                           + PHI2(XC, YC, ZC, T + DT) * DPHI2DY(XC, YC, ZC, T + DT)   &
                           + PHI3(XC, YC, ZC, T + DT) * DPHI3DY(XC, YC, ZC, T + DT)   &
                           + DPHI1DX(XC, YC, ZC, T + DT) + DPHI2DY(XC, YC, ZC, T + DT)&
                           + DPHI3DZ(XC, YC, ZC, T + DT)
                    VISNP = VISFAC * DYH(1, J)
                    VISNC = VISFAC * DYH(2, J)
                    VISNM = VISFAC * DYH(3, J)
                    
                    !(1 + PHI_I ** 2) * D2_DY2
                    VISFAC = PHI1(XC, YC, ZC, T + DT) ** 2 + PHI2(XC, YC, ZC, T + DT) ** 2  &
                           + PHI3(XC, YC, ZC, T + DT) ** 2 + 1
                    VISNP = VISNP + VISFAC * DY2H(1, J)
                    VISNC = VISNC + VISFAC * DY2H(2, J)
                    VISNM = VISNM + VISFAC * DY2H(3, J)
                    
                    NPFAC(J) = NPFAC(J) - VISNP / RE
                    NCFAC(J) = NCFAC(J) - VISNC / RE
                    NMFAC(J) = NMFAC(J) - VISNM / RE
                END DO
                NPFAC = NPFAC / 2 * DT
                NCFAC = NCFAC / 2 * DT + 1
                NMFAC = NMFAC / 2 * DT
                
                !BOUNDARY TERM CORRECT
                R3(I, 1, K) = R3(I, 1, K) - NMFAC(1) * DW(I, 0, K)
                R3(I, N2, K) = R3(I, N2, K) - NPFAC(N2) * DW(I, N2+1, K)
                
                CALL TDMA(NMFAC, NCFAC, NPFAC, DW(I, 1 : N2, K), R3(I, 1 : N2, K))
            END DO
        END DO
        
        NPFAC = 0
        NCFAC = 0
        NMFAC = 0
        
        !SOLVE IN X DIRECTION
        DO K = 1, N3
            DO J = 1, N2
                DO I = 1, N1
                    
                    !D_U^N_W^NP_DX
                    U1 = (U(I, J, KP(K)) + U(I, J, K)) / 2
                    U2 = (U(IP(I), J, KP(K)) + U(IP(I), J, K)) / 2
                    NPFAC(I) = U2 / 2 / DX
                    NCFAC(I) = (U2 - U1) / 2 / DX
                    NMFAC(I) = -U1 / 2 / DX
                    
                    !VISCOS TERM
                    NPFAC(I) = NPFAC(I) - 1 / DX / DX / RE
                    NCFAC(I) = NCFAC(I) + 2 / DX / DX / RE
                    NMFAC(I) = NMFAC(I) - 1 / DX / DX / RE
                END DO
                NPFAC = NPFAC / 2 * DT
                NCFAC = NCFAC / 2 * DT + 1
                NMFAC = NMFAC / 2 * DT
                CALL CTDMA(NMFAC, NCFAC, NPFAC, DW(1:N1, J, K), DW(1:N1, J, K))
            END DO
        END DO
        
        NPFAC = 0
        NCFAC = 0
        NMFAC = 0
        
        !SOLVE IN Z DIRECTION
        DO J = 1, N2
            DO I = 1, N1
                DO K = 1, N3
                    
                    !TIME ADVANCE TERM
                    !NCFAC(K) = 1
                    
                    !D_W^N_W^NP_DZ
                    W1 = (W(I, J, KM(K)) + W(I, J, K)) / 2
                    W2 = (W(I, J, KP(K)) + W(I, J, K)) / 2
                    NPFAC(K) = W2 / 2 / DZ * DT
                    NCFAC(K) = (W2 - W1) / 2 / DZ * DT
                    NMFAC(K) = -W1 / 2 / DZ * DT
                    
                    !VISCOS TERM
                    NPFAC(K) = NPFAC(K) - 1 / DZ / DZ / 2 / RE * DT
                    NCFAC(I) = NCFAC(K) + 1 / DZ / DZ / RE * DT
                    NMFAC(I) = NMFAC(K) - 1 / DZ / DZ / 2 / RE * DT
                END DO
                NCFAC(1:N3) = NCFAC(1:N3) + 1
                CALL CTDMA(NMFAC, NCFAC, NPFAC, DW(I, J, 1:N3), DW(I, J, 1:N3))
            END DO
        END DO
    END SUBROUTINE SOLVE_WH
    
    SUBROUTINE FORM_RP()
        IMPLICIT NONE
        
        REAL D2FAC, DFAC, FAC
        REAL D2PDY, DPDY, C1, C3
        REAL XC, YC, ZC
        INTEGER I, J, K
        
        !BING RP TO R
        RP => R
        
        !GET DIVERSION OF U*
        CALL GETDIV(DU, DV, DW, DIV, T + DT)
        
        !CALCULATE CURVELINEAR COORDINATE ASSOCIATED TERM
        DO K = 1, N3
            ZC = (Z(K) + Z(K - 1)) / 2
            DO I = 1, N1
                XC = (X(I) + X(I - 1)) / 2
                DO J = 2, N2 - 1
                    YC = (Y(J) + Y(J - 1)) / 2
                    
                    D2FAC = PHI2(XC, YC, ZC, T + DT) * 2  &
                          + PHI1(XC, YC, ZC, T + DT) ** 2 &
                          + PHI2(XC, YC, ZC, T + DT) ** 2 &
                          + PHI3(XC, YC, ZC, T + DT) ** 2
                    
                    DFAC = DPHI1DX(XC, YC, ZC, T + DT)  &
                         + DPHI2DY(XC, YC, ZC, T + DT)  &
                         + DPHI3DZ(XC, YC, ZC, T + DT)  &
                         + PHI1(XC, YC, ZC, T + DT) * DPHI1DY(XC, YC, ZC, T + DT)   &
                         + PHI2(XC, YC, ZC, T + DT) * DPHI2DY(XC, YC, ZC, T + DT)   &
                         + PHI3(XC, YC, ZC, T + DT) * DPHI3DY(XC, YC, ZC, T + DT)
                    
                    D2PDY = DY2H(1, J) * DP(I, JP(J), K) + DY2H(2, J) * DP(I, J, K) + DY2H(3, J) * DP(I, JM(J), K)
                    DPDY = DYH(1, J) * DP(I, JP(J), K) + DYH(2, J) * DP(I, J, K) + DYH(3, J) * DP(I, JM(J), K)
                    
                    C1 = (DP(IP(I), JP(J), K) - DP(IM(I), JP(J), K)) * DYH(1, J) &
                       + (DP(IP(I), J, K) - DP(IM(I), J, K)) * DYH(2, J)         &
                       + (DP(IP(I), JM(J), K) - DP(IM(I), JM(J), K)) * DYH(3, J)
                    C1 = C1 / 2 / DX
                    C3 = (DP(I, JP(J), KP(K)) - DP(I, JP(J), KM(K))) * DYH(1, J) &
                       + (DP(I, J, KP(K)) - DP(I, J, KM(K))) * DYH(2, J)         &
                       + (DP(I, JM(J), KP(K)) - DP(I, JM(J), KM(K))) * DYH(3, J)
                    C3 = C3 / 2 / DZ
                    
                    RP(I, J, K) = D2PDY * D2FAC + DPDY * DFAC &
                                + C1 * 2 * PHI1(XC, YC, ZC, T + DT) &
                                + C3 * 2 * PHI3(XC, YC, ZC, T + DT)
                END DO
                !J = 1
                YC = (Y(1) + Y(0)) / 2
                
                D2FAC = PHI2(XC, YC, ZC, T + DT) * 2  &
                        + PHI1(XC, YC, ZC, T + DT) ** 2 &
                        + PHI2(XC, YC, ZC, T + DT) ** 2 &
                        + PHI3(XC, YC, ZC, T + DT) ** 2
                    
                DFAC = DPHI1DX(XC, YC, ZC, T + DT)  &
                        + DPHI2DY(XC, YC, ZC, T + DT)  &
                        + DPHI3DZ(XC, YC, ZC, T + DT)  &
                        + PHI1(XC, YC, ZC, T + DT) * DPHI1DY(XC, YC, ZC, T + DT)   &
                        + PHI2(XC, YC, ZC, T + DT) * DPHI2DY(XC, YC, ZC, T + DT)   &
                        + PHI3(XC, YC, ZC, T + DT) * DPHI3DY(XC, YC, ZC, T + DT)
                
                D2PDY = ((DP(I, 2, K) - DP(I, 1, K)) / H(2) - PB(I, 1, K)) / DY(1)
                DPDY = ((DP(I, 2, K) - DP(I, 1, K)) / H(2) + PB(I, 1, K)) / 2
                
                C1 = ((DP(IP(I), 2, K) - DP(IP(I), 2, K)) / H(2) + PB(IP(I), 1, K)) / 2 &
                   - ((DP(IM(I), 2, K) - DP(IM(I), 2, K)) / H(2) + PB(IM(I), 1, K)) / 2
                C1 = C1 / 2 / DX
                C3 = ((DP(I, 2, KP(K)) - DP(I, 2, KP(K))) / H(2) + PB(I, 1, KP(K))) / 2 &
                   - ((DP(I, 2, KM(K)) - DP(I, 2, KM(k))) / H(2) + PB(I, 1, KM(K))) / 2
                C3 = C3 / 2 / DX
                
                RP(I, 1, K) = D2PDY * D2FAC + DPDY * DFAC &
                            + C1 * 2 * PHI1(XC, YC, ZC, T + DT) &
                            + C3 * 2 * PHI3(XC, YC, ZC, T + DT)
                
                !J = N2
                YC = (Y(N2) + Y(N2-1)) / 2
                
                D2FAC = PHI2(XC, YC, ZC, T + DT) * 2  &
                        + PHI1(XC, YC, ZC, T + DT) ** 2 &
                        + PHI2(XC, YC, ZC, T + DT) ** 2 &
                        + PHI3(XC, YC, ZC, T + DT) ** 2
                    
                DFAC = DPHI1DX(XC, YC, ZC, T + DT)  &
                        + DPHI2DY(XC, YC, ZC, T + DT)  &
                        + DPHI3DZ(XC, YC, ZC, T + DT)  &
                        + PHI1(XC, YC, ZC, T + DT) * DPHI1DY(XC, YC, ZC, T + DT)   &
                        + PHI2(XC, YC, ZC, T + DT) * DPHI2DY(XC, YC, ZC, T + DT)   &
                        + PHI3(XC, YC, ZC, T + DT) * DPHI3DY(XC, YC, ZC, T + DT)
                
                D2PDY = (PB(I, 2, K) - (DP(I, N2, K) - DP(I, N2-1, K)) / H(N2)) / DY(N2)
                DPDY = (PB(I, 2, K) + (DP(I, N2, K) - DP(I, N2-1, K)) / H(N2)) / 2
                
                C1 = (PB(IP(I), 2, K) + (DP(IP(I), N2, K) - DP(IP(I), N2-1, K)) / H(N2)) / 2 &
                   - (PB(IM(I), 2, K) + (DP(IM(I), N2, K) - DP(IM(I), N2-1, K)) / H(N2)) / 2
                C1 = C1 / 2 / DX
                C3 = (PB(I, 2, KP(K)) + (DP(I, N2, KP(K)) - DP(I, N2-1, KP(K))) / H(N2)) / 2 &
                   - (PB(I, 2, KM(K)) + (DP(I, N2, KM(K)) - DP(I, N2-1, KM(K))) / H(N2)) / 2
                C3 = C3 / 2 / DZ
                
                RP(I, N2, K) = D2PDY * D2FAC + DPDY * DFAC &
                             + C1 * 2 * PHI1(XC, YC, ZC, T + DT) &
                             + C3 * 2 * PHI3(XC, YC, ZC, T + DT)
            END DO
        END DO
        
        !CALL DOUTPUT('RP', RP)
        RP = DIV / DT - RP
    END SUBROUTINE FORM_RP
    
    SUBROUTINE SOLVE_DP
        IMPLICIT NONE
        REAL :: ALPHA, BETA
        INTEGER I, J, K, M, N
        REAL XC, YC, ZC
        COMPLEX D2FAC, DFAC, FAC
        COMPLEX, PARAMETER :: II = (0, 1)
        
        CALL FFT(RP, DIVS)
        ALPHA = 2 * PI / LX
        BETA = 2 * PI / LZ
        
        DO K = 1, N3
            ZC = (Z(K) + Z(K - 1)) / 2
            N = K - 1 - N3 / 2
            DO I = 1, N1
                XC = (X(I) + X(I - 1)) / 2
                M = I - 1 - N1 / 2
                DO J = 2, N2 - 1
                    YC = (Y(J) + Y(J - 1)) / 2
                    
                    !D2_DY2 FACTOR
                    
                    !Y FACTOR
                    FAC = 2 * (COS(ALPHA * M * DX) - 1) / DX / DX + 2 * (COS(BETA * N * DZ) - 1) / DZ / DZ
                    
                    PPFAC(J) = DY2H(1, J)
                    PCFAC(J) = DY2H(2, J) + FAC
                    PMFAC(J) = DY2H(3, J)
                END DO
                
                FAC = 2 * (COS(ALPHA * M * DX) - 1) / DX / DX + 2 * (COS(BETA * N * DZ) - 1) / DZ / DZ
                !DFAC = 0
                PPFAC(1) = 1 / DY(1) / H(2)
                PCFAC(1) =-1 / DY(1) / H(2) + FAC
                PMFAC(1) = 0
                DIVS(I, 1, K) = DIVS(I, 1, K) + PBS(I, 1, K) / DY(1)
                
                FAC = 2 * (COS(ALPHA * M * DX) - 1) / DX / DX + 2 * (COS(BETA * N * DZ) - 1) / DZ / DZ
                
                PPFAC(N2) = 0
                PCFAC(N2) = -1 / H(N2) / DY(N2) + FAC
                PMFAC(N2) =  1 / H(N2) / DY(N2)
                DIVS(I, N2, K) = DIVS(I, N2, K) - PBS(I, 2, K) / DY(N2)
                
                !PCFAC(1) = PCFAC(1) + PMFAC(1)
                !PCFAC(N2) = PCFAC(N2) + PPFAC(N2)
                !
                !PMFAC(1) = 0
                !PPFAC(N2) = 0
                
                IF(M == 0 .AND. N == 0) THEN
                    PCFAC(1) = 1
                    PPFAC(1) = 0
                    DIVS(I, 1, K) = 0
                END IF
                
                CALL TDMA(PMFAC, PCFAC, PPFAC, DPS(I, :, K), DIVS(I, :, K))
            END DO
        END DO
        
        CALL IFFT(DPS, DP)
    END SUBROUTINE SOLVE_DP
    
    SUBROUTINE UPDATE_UP()
        IMPLICIT NONE
        
        REAL DPGX, DPGZ
        REAL DPDY
        REAL XC, YC, ZC
        REAL ETA
        INTEGER I, J, K
        
        !GET N TIME STEP FLOW RATE
        CALL CHECK_FLOW_RATE()
        
        !UPDATE U VELOCITY
        !KEEP CONSTANT MASS FLOW RATE
        DPGX = 0
        DO K = 1, N3
            ZC = (Z(K) + Z(K - 1)) / 2
            DO I = 1, N1
                XC = X(I - 1)
                ETA = 1 + GETETA(XC, ZC, T + DT)
                DO J = 2, N2 - 1
                    YC = (Y(J) + Y(J - 1)) / 2
                    DPDY = DYH(1, J) * (DP(I, JP(J), K) + DP(IM(I), JP(J), K))  &
                         + DYH(2, J) * (DP(I, J, K) + DP(IM(I), J, K))          &
                         + DYH(3, J) * (DP(I, JM(J), K) + DP(IM(I), JM(J), K))
                    DPDY = DPDY / 2
                    DPGX = DPGX + (DU(I, J, K) * DY(J) * DX * DZ &
                         - DT * (DP(I, J, K) - DP(IM(I), J, K)) * DY(J) * DZ    &
                         - DT * (PHI1(XC, YC, ZC, T + DT / 2) * DPDY * DX) * DY(J) * DZ) * ETA
                END DO
                
                !J = 1
                J = 1
                YC = (Y(J) + Y(J - 1)) / 2
                DPDY = (DP(I, 2, K) - DP(I, 1, K)) / H(2) + PB(I, 1, K) &
                     + (DP(IM(I), 2, K) - DP(IM(I), 1, K)) / H(2) + PB(IM(I), 1, K)
                DPDY = DPDY / 2
                DPGX = DPGX + (DU(I, J, K) * DY(J) * DX * DZ &
                     - DT * (DP(I, J, K) - DP(IM(I), J, K)) * DY(J) * DZ    &
                     - DT * (PHI1(XC, YC, ZC, T + DT) * DPDY * DX) * DY(J) * DZ) * ETA
                
                !J = N2
                J = N2
                YC = (Y(J) + Y(J - 1)) / 2
                DPDY = PB(I, 2, K) + (DP(I, N2, K) - DP(I, N2-1, K)) / H(N2) &
                     + PB(IM(I), 2, K) + (DP(IM(I), N2, K) - DP(IM(I), N2-1, K)) / H(N2)
                DPDY = DPDY / 2
                DPGX = DPGX + (DU(I, J, K) * DY(J) * DX * DZ &
                     - DT * (DP(I, J, K) - DP(IM(I), J, K)) * DY(J) * DZ    &
                     - DT * (PHI1(XC, YC, ZC, T + DT / 2) * DPDY * DX) * DY(J) * DZ) * ETA
            END DO
        END DO
        
        DPGX = (DPGX - XFLOW * LX) / LX / LY / LZ / DT
        
        DO K = 1, N3
            ZC = (Z(K) + Z(K - 1)) / 2
            DO I = 1, N1
                XC = X(I - 1)
                DO J = 2, N2 - 1
                    YC = (Y(J) + Y(J - 1)) / 2
                    DPDY = DYH(1, J) * (DP(I, JP(J), K) + DP(IM(I), JP(J), K))  &
                         + DYH(2, J) * (DP(I, J, K) + DP(IM(I), J, K))          &
                         + DYH(3, J) * (DP(I, JM(J), K) + DP(IM(I), JM(J), K))
                    DPDY = DPDY / 2
                    U(I, J, K) = DU(I, J, K) - DT * DPGX    &
                               - DT * (DP(I, J, K) - DP(IM(I), J, K)) / DX    &
                               - DT * PHI1(XC, YC, ZC, T + DT / 2) * DPDY
                END DO
                !J = 0
                U(I, 0, K) = U(I, 0, K) + DU(I, 0, K)
                
                !J = 1
                J = 1
                YC = (Y(J) + Y(J - 1)) / 2
                DPDY = (DP(I, 2, K) - DP(I, 1, K)) / H(2) + PB(I, 1, K) &
                     + (DP(IM(I), 2, K) - DP(IM(I), 1, K)) / H(2) + PB(IM(I), 1, K)
                DPDY = DPDY / 2
                U(I, J, K) = DU(I, J, K) - DT * DPGX    &
                           - DT * (DP(I, J, K) - DP(IM(I), J, K)) / DX    &
                           - DT * PHI1(XC, YC, ZC, T + DT) * DPDY
                
                !J = N2
                J = N2
                YC = (Y(J) + Y(J - 1)) / 2
                DPDY = PB(I, 2, K) + (DP(I, N2, K) - DP(I, N2-1, K)) / H(N2) &
                     + PB(IM(I), 2, K) + (DP(IM(I), N2, K) - DP(IM(I), N2-1, K)) / H(N2)
                DPDY = DPDY / 2
                U(I, J, K) = DU(I, J, K) - DT * DPGX    &
                           - DT * (DP(I, J, K) - DP(IM(I), J, K)) / DX    &
                           - DT * PHI1(XC, YC, ZC, T + DT) * DPDY
                
                !J = N2 + 1
                U(I, N2 + 1, K) = U(I, N2 + 1, K) + DU(I, N2 + 1, K)
            END DO
        END DO
        
        !UPDATE V VELOCITY
        DO K = 1, N3
            ZC = (Z(K) + Z(K - 1)) / 2
            DO J = 2, N2
                YC = Y(J - 1)
                DO I = 1, N1
                    XC = (X(I) + X(I - 1)) / 2
                    
                    DPDY = (DP(I, J, K) - DP(I, JM(J), K)) / H(J)
                    V(I, J, K) = DV(I, J, K)    &
                               - DT * (1 + PHI2(XC, YC, ZC, T + DT)) * DPDY
                END DO
            END DO
        END DO
        
        DO K = 1, N3
            DO I = 1, N1
                V(I, 1, K) = V(I, 1, K) + DV(I, 1, K)
                V(I, N2 + 1, K) = V(I, N2 + 1, K) + DV(I, N2 + 1, K)
            END DO
        END DO
        
        !UPDATE W VELOCITY
        !KEEP 0 FLOW RATE
        DPGZ = 0
        DO K = 1, N3
            ZC = Z(K - 1)
            DO I = 1, N1
                XC = (X(I) + X(I - 1)) / 2
                ETA = 1 + GETETA(XC, ZC, T + DT)
                DO J = 2, N2 - 1
                    YC = (Y(J) + Y(J - 1)) / 2
                    DPDY = DYH(1, J) * (DP(I, JP(J), K) + DP(I, JP(J), KM(K)))  &
                         + DYH(2, J) * (DP(I, J, K) + DP(I, J, KM(K)))          &
                         + DYH(3, J) * (DP(I, JM(J), K) + DP(I, JM(J), KM(K)))
                    DPDY = DPDY / 2
                    DPGZ = DPGZ + (DW(I, J, K) * DY(J) * DX * DZ &
                         - DT * (DP(I, J, K) - DP(I, J, KM(K))) * DX * DY(J) &
                         - DT * (PHI3(XC, YC, ZC, T + DT) * DPDY * DZ) * DY(J) * DX) * ETA
                END DO
                
                !J = 1
                J = 1
                YC = (Y(J) + Y(J - 1)) / 2
                DPDY = (DP(I, 2, K) - DP(I, 1, K)) / H(2) + PB(I, 1, K) &
                     + (DP(I, 2, KM(K)) - DP(I, 1, KM(K))) / H(2) + PB(I, 1, KM(K))
                DPDY = DPDY / 2
                DPGZ = DPGZ + (DW(I, J, K) * DY(J) * DX * DZ &
                     - DT * (DP(I, J, K) - DP(I, J, KM(K))) * DX * DY(J) &
                     - DT * (PHI3(XC, YC, ZC, T + DT) * DPDY * DZ) * DY(J) * DX) * ETA
                
                !J = N2
                J = N2
                DPDY = PB(I, 2, K) + (DP(I, N2, K) - DP(I, N2-1, K)) / H(N2) &
                     + PB(I, 2, KM(K)) + (DP(I, N2, KM(K)) - DP(I, N2-1, KM(K))) / H(N2)
                DPDY = DPDY / 2
                DPGZ = DPGZ + (DW(I, J, K) * DY(J) * DX * DZ &
                     - DT * (DP(I, J, K) - DP(I, J, KM(K))) * DX * DY(J) &
                     - DT * (PHI3(XC, YC, ZC, T + DT) * DPDY * DZ) * DY(J) * DX) * ETA
            END DO
        END DO
        
        DPGZ = (DPGZ - ZFLOW * LZ) / LX / LY / LZ / DT
        
        DO K = 1, N3
            ZC = Z(K - 1)
            DO I = 1, N1
                XC = (X(I) + X(I - 1)) / 2
                DO J = 2, N2 - 1
                    YC = (Y(J) + Y(J - 1)) / 2
                    DPDY = DYH(1, J) * (DP(I, JP(J), K) + DP(I, JP(J), KM(K)))  &
                         + DYH(2, J) * (DP(I, J, K) + DP(I, J, KM(K)))          &
                         + DYH(3, J) * (DP(I, JM(J), K) + DP(I, JM(J), KM(K)))
                    DPDY = DPDY / 2
                    W(I, J, K) = DW(I, J, K) - DT * DPGZ    &
                         - DT * (DP(I, J, K) - DP(I, J, KM(K))) / DZ &
                         - DT * PHI3(XC, YC, ZC, T + DT) * DPDY
                END DO
                !J = 0
                W(I, 0, K) = W(I, 0, K) + DW(I, 0, K)
                
                !J = 1
                J = 1
                YC = (Y(J) + Y(J - 1)) / 2
                DPDY = (DP(I, 2, K) - DP(I, 1, K)) / H(2) + PB(I, 1, K) &
                     + (DP(I, 2, KM(K)) - DP(I, 1, KM(K))) / H(2) + PB(I, 1, KM(K))
                DPDY = DPDY / 2
                W(I, J, K) = DW(I, J, K) - DT * DPGZ    &
                           - DT * (DP(I, J, K) - DP(I, J, KM(K))) / DZ &
                           - DT * PHI3(XC, YC, ZC, T + DT) * DPDY
                
                !J = N2
                J = N2
                DPDY = PB(I, 2, K) + (DP(I, N2, K) - DP(I, N2-1, K)) / H(N2) &
                     + PB(I, 2, KM(K)) + (DP(I, N2, KM(K)) - DP(I, N2-1, KM(K))) / H(N2)
                DPDY = DPDY / 2
                W(I, J, K) = DW(I, J, K) - DT * DPGZ    &
                           - DT * (DP(I, J, K) - DP(I, J, KM(K))) / DZ &
                           - DT * PHI3(XC, YC, ZC, T + DT) * DPDY
                
                !J = N2 + 1
                W(I, N2 + 1, K) = W(I, N2 + 1, K) + DW(I, N2 + 1, K)
            END DO
        END DO
        
        !UPDATE PRESSURE
        P = P + DP
        PGX = PGX + DPGX
        PGZ = PGZ + DPGZ
    END SUBROUTINE UPDATE_UP

    SUBROUTINE OUTPUT()
        IMPLICIT NONE
        INTEGER I, J, K
        CHARACTER(LEN = 10) NUM
        CHARACTER(LEN = 50) PATH
        
        WRITE(NUM, 110) CURNT_STEP_NUM
110     FORMAT(I10)
        PATH = TRIM(ADJUSTL(SAVE_FILE_PATH))//'U_'//TRIM(ADJUSTL(NUM))//'.DAT'
        OPEN(111, FILE = PATH, FORM = 'BINARY', STATUS = 'REPLACE')
        WRITE(111) (((U(I, J, K), I = 1, N1), J = 1, N2), K = 1, N3)
        WRITE(111) (((V(I, J, K), I = 1, N1), J = 1, N2), K = 1, N3)
        WRITE(111) (((W(I, J, K), I = 1, N1), J = 1, N2), K = 1, N3)
        CLOSE(111)
        PATH = TRIM(ADJUSTL(SAVE_FILE_PATH))//'P_'//TRIM(ADJUSTL(NUM))//'.DAT'
        OPEN(112, FILE = PATH, FORM = 'BINARY', STATUS = 'REPLACE')
        WRITE(112) (((P(I, J, K), I = 1, N1), J = 1, N2), K = 1, N3)
        CLOSE(112)
        PATH = TRIM(ADJUSTL(SAVE_FILE_PATH))//'DIV_'//TRIM(ADJUSTL(NUM))//'.DAT'
        OPEN(113, FILE = PATH, FORM = 'BINARY', STATUS = 'REPLACE')
        WRITE(113) (((DIV(I, J, K), I = 1, N1), J = 1, N2), K = 1, N3)
        CLOSE(113)
    END SUBROUTINE OUTPUT

    END MODULE FIELD
