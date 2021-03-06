program Project1a
	use helper
	use ogpf
	use linAlg
	implicit none
	
	!print *, 'Hello World'
	
!Variables
	!general
	integer, parameter :: qp = selected_real_kind(33, 4931) !for quad precision
	character(100) :: buffer
	logical :: flag
	integer :: i, j, cnt
	character(1) :: c !single character holder

	!Problem Specific
	real(16) :: temp !temperature assumed Kelvin
	real(16), allocatable :: guess(:), deltaGuess(:) !paramenters
	real(16), allocatable :: dataPoints(:,:)
	integer :: M, N !number of paramenters 
	character(10) :: unitsX, unitsY, funcs !(unitX,unitY)
	real(16) :: lambda = 10000 !starting value of lambda
	real(16) :: error, newError, deltaError !Can I real(16)ly declare them this way?
	real(16), allocatable :: beta(:), alpha(:,:), alphaMod(:,:), alphaSolve(:) 
	real(16) :: variance
	real(16), allocatable :: standDev(:), corCoef(:,:)

	!plotting variables
	TYPE(gpf) :: gp
	real(wp), allocatable :: x(:), y(:), yfit(:)

	!get command line input
	if (COMMAND_ARGUMENT_COUNT() >= 1) then
		call GET_COMMAND_ARGUMENT(1, buffer)
	end if
	
	!this is a test function 
	if (buffer == '-echo') then
		call get_command_argument(2, buffer)
		print *, buffer
		stop
	end if
	
	
	!opening the file
	inquire(file = buffer, Exist = flag)
	if (flag) then
		open(1, file = buffer, status = 'old')
	else if(flag .eqv. .false.) then
		print *, 'That file name will not do. Exiting.'
		stop
	end if
	
	
!reading the data
	read(1, '(A)') buffer
	print *, buffer
	
	!paramenters and function name
	if(index(buffer, 'virial') /= 0) then
		read(1, *) funcs, M
	else
		read(1, *) funcs
		M = 2
	end if
	call lowerCase(funcs)
	print *, funcs, M
	allocate(guess(M))
	allocate(deltaGuess(M))
	read(1, *) guess
	print '(/,A,*(G0.6,:,", "),A)','Initial guess:  (', guess, ')'
	
	!temperature
	read(1, *) buffer, temp, buffer
	print '(A,f10.2,A)', 'temp: ', temp, 'K '
	
	!units
	read(1, '(a)') buffer
	call lowerCase(buffer)
	c = buffer(1:1)
	i = 1
	do while(c /= ' ')
		i = i + 1
		c = buffer(i:i)
	end do
	unitsX = buffer(1:i)
	unitsY = buffer(i+1:)
	print *, 'Units of volume: ', unitsX
	print *, 'Units of pressure: ', unitsY
	
	!the data points
	N = 0
	i = 0
	do while(i == 0)
		read(1, '(A)', IOstat = i) buffer
		N = N + 1
		!print *, buffer, " N: ", N
	end do
	rewind 1
	N = N-1
	print '(/,A,i5,A)','There are ', N, ' data points'
	allocate(dataPoints(2, N))
	do i=0, 4
		read(1, '(A)') buffer
		!print *, buffer
	end do
	read(1, *) dataPoints
	do i=1, 10
		print '(i2,A,2(es10.3,2x,A,4x))', i, ":   ", dataPoints(1,i), unitsX, dataPoints(2, i), unitsY
	end do
	
	!Convert to SI units
	print '(/,A)', 'Converting to SI units'
	select case (unitsX)
		case ('dm^3/mol')
			dataPoints(1,:) =  dataPoints(1,:) * 1.e-3_qp
		case ('m^3/mol')
			dataPoints(1,:) = dataPoints(1,:) 
		case ('cm^3/mol')
			dataPoints(1,:) = dataPoints(1,:) * 1.e-6_qp
		case ('l/mol')
			dataPoints(1,:) = dataPoints(1,:) * 1.e-3_qp
	end select
	unitsX = 'm^3/mol'
	select case (unitsY)
		case ('pa')
			dataPoints(2,:) = dataPoints(2,:) 
		case ('megapa')
			dataPoints(2,:) = dataPoints(2,:) * 1.e+6_qp
		case ('kilobar')
			dataPoints(2,:) = dataPoints(2,:) * 1.e+8_qp
		case ('bar')
			dataPoints(2,:) = dataPoints(2,:) * 1.e+5_qp
		case ('atm')
			dataPoints(2,:) = dataPoints(2,:) * 101325._qp
		case ('torr')
			dataPoints(2,:) = dataPoints(2,:) * 101325._qp / 760._qp
		case ('mmhg')
			dataPoints(2,:) = dataPoints(2,:) * 133.322387415_qp
	end select
	unitsY = 'pa'
	do i=1, 10
		print '(i2,A,2(es10.3,2x,A,4x))', i, ":   ", dataPoints(1,i), unitsX, dataPoints(2, i), unitsY
	end do
	
	!other allocations
	allocate(beta(M))
	allocate(alpha(M,M))
	allocate(alphaMod(M,M))
	allocate(alphaSolve(M))
	allocate(standDev(M))
	allocate(corCoef(M,M))
	allocate(x(N)) !for plotting
	allocate(y(N)) !for plotting
	allocate(yfit(N))
	
	!initial plot of data
	call gp%title('Plot of data after converting to SI units')
	x = dataPoints(1,:)
	y = dataPoints(2,:)
	call gp%plot(x, y)


!the good stuff
	flag = .true.
	cnt = 0
	i = 1
	do while(cnt < 1)
		print '(/,/,A)', '-------------------------------------------------------------------------------------'
		print '(/,A,i3,/)', 'cycle: ', i
		print '(A,es10.3)', 'lambda: ', lambda
		if (flag) then
			error = findError(funcs, dataPoints, N, temp, guess, M)
			print '(A,es10.3)', 'The Error is ', error
			
			!beta
			beta = makeBeta(funcs, dataPoints, N, temp, guess, M)
			print '(/,A,*(es10.3,2x))', 'The beta array is: ', beta
			
			!alpha
			alpha = makeAlpha(funcs, dataPoints, N, temp, guess, M)
		end if
		
		print '(/,A)', 'The alpha array:'
		do j=1, M
			print '(*(es10.3,2x))', alpha(j, :)
		end do
		
		!alpha prime
		alphaMod = modAlpha(alpha, M, lambda)
		print '(/,A)', 'The modified alpha array:'
		do j=1, M
			print '(*(es10.3,2x))', alphaMod(j, :)
		end do
		
		!linear solve
		alphaSolve = linSolv(alphaMod, M, beta)
		print '(/,A)', 'The change in the parameters is: '
		print '(*(es10.3,2x))', alphaSolve
		
		deltaGuess = guess + alphaSolve	!This line is the issue. 
		print '(/,A,*(es10.3,2x))', 'old parameters: ', guess
		print '(/,A,*(es10.3,2x))', 'new parameters: ', deltaGuess
		
		newError = findError(funcs, dataPoints, N, temp, deltaGuess, M)
		deltaError = error - newError
		print '(/,A,es10.3)', 'old error: ', error
		print '(A,es10.3)', 'new error: ', newError
		print '(A,es10.3)', 'change in error: ', deltaError
		
		if (deltaError <= 0) then
			lambda = lambda * 10._qp
			flag = .false.
		else if (deltaError > 0) then
			lambda = lambda / 10._qp
			flag = .true.
			guess = deltaGuess
			print '(/,A)', 'New parameters accepted'
		else
			print '(/,A)', 'There were only two options...how did you get here?'
		end if
		
		!stopping condition
		if (abs(deltaError) < 1.e-10_qp) then
			cnt = cnt + 1
		end if
		!failsafe
		if (i>=50) then 
			cnt = 5
		end if
		
		i = i + 1
	end do
	
!Final Statistics
	print '(/,/,A,/)', "-----------------------------------------------"
	print *, 'Final Statistics'
	
	print '(/,A,es10.3)', 'chi square: ', newError
	
	variance = findVariance(funcs, dataPoints, N, temp, guess, M)
	print '(/,A,es10.3)', 'sample variance: ', variance
	
	print '(/,A)', 'variance-covariance matric C:'
	alphaMod = invert(alphaMod, M)
	do i=1, M
		print '(*(es10.3,2x))', alphaMod(i,:)
	end do
	
	print '(/,A,*(es10.3,2x))', 'Final paramenters: ', guess
	
        print '(/,A)', 'Standard Deviation:'
	do i=1, M
		standDev(i) = sqrt(variance * alphaMod(i,i))
	end do
	print '(*(es10.3,2x))', standDev

	if( M > 1) then
		print '(/,A)', 'correlation coefficient: '
		do i=1, M
			do j=1, M
				corCoef(i,j) = (variance * alphaMod(i,j))/(sqrt(variance * alphaMod(i,i)) * sqrt(variance & 
				* alphaMod(j,j)))	
			end do
			print '(*(f10.8, 2x))', corCoef(i,:)
		end do
	end if
	
	print '(/,A,f10.8)', 'coefficient of determination R squared: ', 1 - (newError / sumSquared(dataPoints, N))
	print '(/,A,f10.8)', 'R bar squared: ', 1 - (newError * (real(N, 16) - 1))/(sumSquared(dataPoints, N) * real(N -M -1, 16))
	print '(/,A,es10.4,A)', 'R-Factor: ', 100 * findRFact(funcs, dataPoints, N, temp, guess, M), '%'
	
	!end final paramenters
	
!graphing
	!output file
	call GET_COMMAND_ARGUMENT(1, buffer)
	c = buffer(1:1)
	i = 1
	do while(c /= '.')
		i = i + 1
		c = buffer(i:i)
	end do
	buffer(i:) = '.csv'
	open(2, file = buffer)
	write(2,'(*(G0.6,:,","))') 'Volume', 'Observed Pressure', 'Calculated Pressure'
	do i=1, N
		write(2,'(*(G0.6,:,","))') dataPoints(1,i),dataPoints(2,i),fit(funcs, temp, guess, M, dataPoints(1,i), 0)
		yfit(i) = fit(funcs, temp, guess, M, dataPoints(1,i), 0)
	end do
	print *, 'The observed data and fitted data have been written to ', buffer
	
	!plot with ogpf	
	call gp%title('Final plot')
	call gp%options('set key top right')
	x = dataPoints(1,:)
	y = dataPoints(2,:)
	call gp%plot(x, yfit, 'title "fitted data" with lines lt 5 lc rgb "#0008B0"')
	
	
	!clean up
	close(1)
	close(2)
end program Project1a

	! AV: http://computer-programming-forum.com/49-fortran/4075a24f74fcc9ce.ht
subroutine lowerCase(word)
! convert a word to lower case
	character (len=*) , intent(in out) :: word
	integer                            :: i,ic,nlen
	nlen = len(word)
	do i=1,nlen
	   ic = ichar(word(i:i))
	   if (ic >= 65 .and. ic < 90) word(i:i) = char(ic+32)
	end do
end subroutine lowerCase

