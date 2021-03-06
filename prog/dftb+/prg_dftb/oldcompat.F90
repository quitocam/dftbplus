!--------------------------------------------------------------------------------------------------!
!  DFTB+: general package for performing fast atomistic simulations                                !
!  Copyright (C) 2018  DFTB+ developers group                                                      !
!                                                                                                  !
!  See the LICENSE file for terms of usage and distribution.                                       !
!--------------------------------------------------------------------------------------------------!

!> Contains routines to convert HSD input for old parser to the current format.
!> Note: parserVersion is set in parser.F90
module oldcompat
  use accuracy, only : dp
  use message
  use hsdutils
  use hsdutils2
  use charmanip
  use xmlutils
  use xmlf90
  implicit None
  private

  public :: convertOldHSD

contains


  !> Converts an HSD input for an older parser to the current format
  subroutine convertOldHSD(root, oldVersion, curVersion)

    !> Root tag of the HSD-tree
    type(fnode), pointer :: root

    !> Version number of the old parser
    integer, intent(in) :: oldVersion

    !> Version number of the current parser
    integer, intent(in) :: curVersion

    integer :: version
    type(fnode), pointer :: ch1, ch2, par

    version = oldVersion
    do while (version < curVersion)
      select case(version)
      case(1)
        call convert_1_2(root)
        version = 2
      case(2)
        call convert_2_3(root)
        version = 3
      case (3)
        call convert_3_4(root)
        version = 4
      case (4)
        call convert_4_5(root)
        version = 5
      case (5)
        call convert_5_6(root)
        version = 6
      end select
    end do

    ! increase the parser version number in the tree - since the resulting dftb_pin would not work
    ! with the old parser as the options have changed to the new parser by now
    call getChildValue(root, "ParserOptions", ch1, "", child=par, &
        &allowEmptyValue=.true.)
    call getChildValue(par, "ParserVersion", version, child=ch2)
    call setChildValue(ch2, "", curVersion, replace=.true.)

  end subroutine convertOldHSD


  !> Converts input from version 1 to 2. (Version 2 introcuded in August 2006)
  subroutine convert_1_2(root)

    !> Root tag of the HSD-tree
    type(fnode), pointer :: root

    type(fnode), pointer :: child1, child2

    call getChild(root, "Geometry", child1, requested=.false.)
    if (associated(child1)) then
      call setUnprocessed(child1)
      call getChild(child1, "SpeciesNames", child2, requested=.false.)
      if (associated(child2)) then
        call setUnprocessed(child2)
        call setNodeName(child2, "TypeNames")
      end if
    end if

  end subroutine convert_1_2


  !> Converts input from version 2 to 3. (Version 3 introduced in Nov. 2006)
  subroutine convert_2_3(root)

    !> Root tag of the HSD-tree
    type(fnode), pointer :: root

    type(fnode), pointer :: ch1, ch2, par
    logical :: tValue

    call getDescendant(root, &
        &"Driver/VelocityVerlet/Thermostat/Andersen/RescalingProbability", &
        &ch1)
    if (associated(ch1)) then
      call detailedWarning(ch1, "Keyword renamed to 'ReselectProbability'.")
      call setNodeName(ch1, "ReselectProbability")
    end if

    call getDescendant(root, &
        &"Driver/VelocityVerlet/Thermostat/Andersen/RescaleIndividually", &
        &ch1)
    if (associated(ch1)) then
      call detailedWarning(ch1, "Keyword renamed to 'ReselectIndividually'.")
      call setNodeName(ch1, "ReselectIndividually")
    end if

    call getDescendant(root, "Hamiltonian/DFTB/Variational", ch1)
    if (associated(ch1)) then
      call getChildValue(ch1, "", tValue)
      call setUnprocessed(ch1)
      if (.not. tValue) then
        call detailedError(ch1, "Sorry, non-variational energy calculation &
            &is not supported any more!")
      else
        call detailedWarning(ch1, "Energy calculation is made only &
            &variational, option removed.")
        call destroyNode(ch1)
      end if
    end if

    call getDescendant(root, "Hamiltonian/DFTB/SCC", ch1, parent=par)
    if (associated(ch1)) then
      call getChildValue(ch1, "", tValue)
      call setUnprocessed(ch1)
      if (tValue) then
        call setChildValue(par, "OrbitalResolvedSCC", .true., child=ch2)
        call setUnprocessed(ch2)
        call detailedWarning(ch2, "Calculations are not orbital resolved &
            &per default any more. Keyword 'OrbitalResolvedSCC' added.")
      end if
    end if

    call getDescendant(root, "Options/PrintEigenvectors", ch1)
    if (associated(ch1)) then
      call detailedWarning(ch1, "Keyword converted to 'WriteEigenvectors'")
      call setNodeName(ch1, "WriteEigenvectors")
    end if

    call getDescendant(root, "Options/WriteTaggedOut", ch1)
    if (associated(ch1)) then
      call detailedWarning(ch1, "Keyword converted to 'WriteAutotestTag'. &
          &Output file name changed to 'autotest.out'")
      call setNodeName(ch1, "WriteAutotestTag")
    end if

    call getDescendant(root, "Options/WriteBandDat", ch1)
    if (associated(ch1)) then
      call detailedWarning(ch1, "Keyword converted to 'WriteBandOut'. &
          &Output file name changed to 'band.out'")
      call setNodeName(ch1, "WriteBandOut")
    end if

  end subroutine convert_2_3


  !> Converts input from version 3 to 4. (Version 4 introduced in Mar. 2010)
  subroutine convert_3_4(root)

    !> Root tag of the HSD-tree
    type(fnode), pointer :: root

    type(fnode),pointer :: node, node2, node3
    type(fnodeList), pointer :: children
    integer :: ii

    ! Replace range operator with short start:end syntax
    call getDescendant(root, "Driver/SteepestDescent/MovedAtoms", node)
    call replaceRange(node)
    call getDescendant(root, "Driver/ConjugateGradient/MovedAtoms", node)
    call replaceRange(node)
    call getDescendant(root, "Driver/SecondDerivatives/Atoms", node)
    call replaceRange(node)
    call getDescendant(root, "Driver/VelocityVerlet/MovedAtoms", node)
    call replaceRange(node)
    call getDescendant(root, "Hamiltonian/DFTB/SpinPolarisation/Colinear&
        &/InitialSpin", node)
    if (associated(node)) then
      call getChildren(node, "AtomSpin", children)
      do ii = 1, getLength(children)
        call getItem1(children, ii, node2)
        call getChild(node2, "Atoms", node3)
        call replaceRange(node3)
      end do
      call destroyNodeList(children)
    end if

    call getDescendant(root, "Hamiltonian/DFTB/SpinPolarisation/Colinear&
        &/InitialSpin", node)
    if (associated(node)) then
      call detailedWarning(node, "Keyword renamed to 'InitalSpins'.")
      call setNodeName(node, "InitialSpins")
    end if

  end subroutine convert_3_4

  !> Helper function for Range keyword in convert_3_4
  subroutine replaceRange(node)

    !> node to process
    type(fnode), pointer :: node

    type(fnode), pointer :: node2
    integer :: bounds(2)

    if (associated(node)) then
      call getChild(node, "Range", node2, requested=.false.)
      if (associated(node2)) then
        call getChildValue(node2, "", bounds)
        call removeChildNodes(node)
        call setChildValue(node, "", &
            &i2c(bounds(1)) // ":" // i2c(bounds(2)), replace=.true.)
        call detailedWarning(node, "Specification 'Range { start end }' &
            &not supported any more, using 'start:end' instead")
      end if
    end if

  end subroutine replaceRange


  !> Converts input from version 4 to 5. (Version 5 introduced in Dec. 2014)
  subroutine convert_4_5(root)

    !> Root tag of the HSD-tree
    type(fnode), pointer :: root

    type(fnode), pointer :: ch1, ch2, ch3, par, dummy
    logical :: tVal

    call getDescendant(root, "Hamiltonian/DFTB/Eigensolver/Standard", ch1)
    if (associated(ch1)) then
      call detailedWarning(ch1, "Keyword renamed to 'QR'.")
      call setNodeName(ch1, "QR")
    end if

    call getDescendant(root, "Options/MullikenAnalysis", ch1, parent=par)
    if (associated(ch1)) then
      call getChildValue(ch1, "", tVal)
      call detailedWarning(ch1, "Keyword moved to Analysis block.")
      dummy => removeChild(par, ch1)
      call destroyNode(ch1)
      call getChildValue(root, "Analysis", dummy, "", child=ch1, list=.true., &
          & allowEmptyValue=.true., dummyValue=.true.)
      if (.not.associated(ch1)) then
        call setChild(root, "Analysis", ch1)
      end if
      call setChildValue(ch1, "MullikenAnalysis", tVal)
      call setUnprocessed(ch1)
    end if

    call getDescendant(root, "Options/AtomResolvedEnergies", ch1, parent=par)
    if (associated(ch1)) then
      call getChildValue(par, "AtomResolvedEnergies", tVal)
      call detailedWarning(ch1, "Keyword moved to Analysis block.")
      dummy => removeChild(par,ch1)
      call destroyNode(ch1)
      call getChildValue(root, "Analysis", dummy, "", child=ch1, list=.true., &
          &allowEmptyValue=.true., dummyValue=.true.)
      if (.not.associated(ch1)) then
        call setChild(root, "Analysis", ch1)
      end if
      call setChildValue(ch1,"AtomResolvedEnergies",tVal)
      call setUnprocessed(ch1)
    end if

    call getDescendant(root, "Options/WriteEigenvectors", ch1, parent=par)
    if (associated(ch1)) then
      call getChildValue(par, "WriteEigenvectors", tVal)
      call detailedWarning(ch1, "Keyword moved to Analysis block.")
      dummy => removeChild(par, ch1)
      call destroyNode(ch1)
      call getChildValue(root, "Analysis", dummy, "", child=ch1, list=.true., &
          &allowEmptyValue=.true., dummyValue=.true.)
      if (.not.associated(ch1)) then
        call setChild(root, "Analysis", ch1)
      end if
      call setChildValue(ch1, "WriteEigenvectors", tVal)
      call setUnprocessed(ch1)
    end if

    call getDescendant(root, "Options/WriteBandOut", ch1, parent=par)
    if (associated(ch1)) then
      call getChildValue(par, "WriteBandOut", tVal)
      call detailedWarning(ch1, "Keyword moved to Analysis block.")
      dummy => removeChild(par, ch1)
      call destroyNode(ch1)
      call getChildValue(root, "Analysis", dummy, "", child=ch1, list=.true., &
          & allowEmptyValue=.true., dummyValue=.true.)
      if (.not.associated(ch1)) then
        call setChild(root, "Analysis", ch1)
      end if
      call setChildValue(ch1, "WriteBandOut", tVal)
      call setUnprocessed(ch1)
    end if

    call getDescendant(root, "Options/CalculateForces", ch1, parent=par)
    if (associated(ch1)) then
      call getChildValue(par, "CalculateForces", tVal)
      call detailedWarning(ch1, "Keyword moved to Analysis block.")
      dummy => removeChild(par,ch1)
      call destroyNode(ch1)
      call getChildValue(root, "Analysis", dummy, "", child=ch1, list=.true., &
          &allowEmptyValue=.true., dummyValue=.true.)
      if (.not.associated(ch1)) then
        call setChild(root, "Analysis", ch1)
      end if
      call setChildValue(ch1, "CalculateForces", tVal)
      call setUnprocessed(ch1)
    end if

    call getDescendant(root, "Hamiltonian/DFTB", ch1, parent=par)
    if (associated(ch1)) then
      call setChild(ch1, "Differentiation", ch2)
      call setChild(ch2, "FiniteDiff", ch3)
      call setChildValue(ch3, "Delta", 1.0e-2_dp)
      call detailedWarning(ch2, "Adding legacy step size for finite difference&
          & differentiation")
    end if

    call getDescendant(root, "Hamiltonian/DFTB/SpinConstants", ch1, parent=par)
    if (associated(ch1)) then
      call setChildValue(ch1, "ShellResolvedSpin", .true.)
    end if

  end subroutine convert_4_5

  !> Converts input from version 5 to 6. (Version 6 introduced in May. 2018)
  subroutine convert_5_6(root)

    !> Root tag of the HSD-tree
    type(fnode), pointer :: root

    type(fnode), pointer :: ch1, ch2, ch3, ch4, par, par2, dummy
    logical :: tVal, tVal2
    real(dp) :: rTmp

    call getDescendant(root, "Analysis/Localise/PipekMezey/Tollerance", ch1)
    if (associated(ch1)) then
      call detailedWarning(ch1, "Keyword converted to 'Tolerance'.")
      call setNodeName(ch1, "Tolerance")
    end if

    call getDescendant(root, "Analysis/Localise/PipekMezey/SparseTollerances", ch1)
    if (associated(ch1)) then
      call detailedWarning(ch1, "Keyword converted to 'SparseTollerances'.")
      call setNodeName(ch1, "SparseTolerances")
    end if

    call getDescendant(root, "Hamiltonian/DFTB/DampXH", ch1, parent=par)
    if (associated(ch1)) then
      call getChildValue(par, "DampXH", tVal)
      call getDescendant(root, "Hamiltonian/DFTB/DampXHExponent", ch2)
      if (tVal .neqv. associated(ch2)) then
        call error("Incompatible combinaton of DampXH and DampXHExponent")
      end if
      if (associated(ch2)) then
        call getChildValue(par, "DampXHExponent", rTmp)
      end if
      call detailedWarning(ch1, "Keyword DampXH moved to HCorrection block")
      dummy => removeChild(par,ch1)
      call destroyNode(ch1)
      dummy => removeChild(par,ch2)
      call destroyNode(ch2)

      ! clean out any HCorrection entry
      call getDescendant(root, "Hamiltonian/DFTB/HCorrection", ch2, parent=par)
      if (associated(ch2)) then
        call detailedError(ch2, "HCorrection already present.")
      end if

      call getDescendant(root, "Hamiltonian/DFTB", ch2, parent=par)
      call setChild(ch2, "HCorrection", ch3)
      call setChild(ch3, "Damping", ch4)
      call setChildValue(ch4, "Exponent", rTmp)
      call detailedWarning(ch3, "Adding Damping to HCorrection")
    end if

  end subroutine convert_5_6

end module oldcompat
