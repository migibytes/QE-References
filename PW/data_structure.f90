!
! Copyright (C) 2001-2010 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!
!-----------------------------------------------------------------------
SUBROUTINE data_structure( gamma_only )
  !-----------------------------------------------------------------------
  ! this routine sets the data structure for the fft arrays
  ! (both the smooth and the dense grid)
  ! In the parallel case, it distributes columns to processes, too
  !
  USE kinds,      ONLY : DP
  USE io_global,  ONLY : stdout
  USE mp,         ONLY : mp_sum, mp_max
  USE mp_global,  ONLY : intra_pool_comm, inter_pool_comm, use_task_groups
  USE fft_base,   ONLY : dfftp, dffts
  USE cell_base,  ONLY : bg, tpiba
  USE klist,      ONLY : xk, nks
  USE gvect,      ONLY : ngm, ngm_g, gcutm
  USE gvecs,      ONLY : ngms, ngms_g, gcutms
  USE stick_base, ONLY : pstickset
  USE task_groups,ONLY : task_groups_init
  USE wvfct,      ONLY : ecutwfc

  !
  IMPLICIT NONE
  LOGICAL, INTENT(in) :: gamma_only
  REAL (DP) :: gkcut
  INTEGER :: ik, ngw_
  !
  ! ... calculate gkcut = max |k+G|^2, in (2pi/a)^2 units
  !
  IF (nks == 0) THEN
     !
     ! if k-points are automatically generated (which happens later)
     ! use max(bg)/2 as an estimate of the largest k-point
     !
     gkcut = 0.5d0 * max ( &
        sqrt (sum(bg (1:3, 1)**2) ), &
        sqrt (sum(bg (1:3, 2)**2) ), &
        sqrt (sum(bg (1:3, 3)**2) ) )
  ELSE
     gkcut = 0.0d0
     DO ik = 1, nks
        gkcut = max (gkcut, sqrt ( sum(xk (1:3, ik)**2) ) )
     ENDDO
  ENDIF
  gkcut = (sqrt (ecutwfc) / tpiba + gkcut)**2
  !
  ! ... find maximum value among all the processors
  !
  CALL mp_max (gkcut, inter_pool_comm )
  !
  ! ... set up fft descriptors, including parallel stuff: sticks, planes, etc.
  !
  CALL pstickset( gamma_only, bg(1,1), bg(1,2), bg(1,3), &
        gcutm, gkcut, gcutms, dfftp, dffts, ngw_ , ngm , ngms )
  !
  !     on output, ngm and ngms contain the local number of G-vectors
  !     for the two grids. Compute here the global number of G-vectors,
  !     i.e. the sum over all processors within a pool
  !
  ngm_g  = ngm  ; CALL mp_sum( ngm_g , intra_pool_comm )
  ngms_g = ngms ; CALL mp_sum( ngms_g, intra_pool_comm )
  !
  IF( use_task_groups ) THEN
    !
    !  Initialize task groups.
    !  Note that this call modify dffts adding task group data.
    !
    CALL task_groups_init( dffts )
    !
  ENDIF

END SUBROUTINE data_structure

