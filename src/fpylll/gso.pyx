from gmp.mpz cimport mpz_t
from qd.qd cimport dd_real, qd_real
from mpfr.mpfr cimport mpfr_t
from integer_matrix cimport IntegerMatrix
from fplll cimport MatGSO as MatGSO_c, Z_NR, FP_NR, Matrix
from fplll cimport GSO_DEFAULT
from fplll cimport GSO_INT_GRAM
from fplll cimport GSO_ROW_EXPO
from fplll cimport GSO_OP_FORCE_LONG
from fplll cimport getCurrentSlope, computeGaussHeurDist
from util cimport preprocess_indices
from fpylll cimport mpz_double, mpz_mpfr, mpz_dd, mpz_qd

class MatGSORowOpContext(object):
    """
    A context in which performing row operations is safe.  When the context is left, the appropriate
    updates are performed by calling ``row_op_end()``.
    """
    def __init__(self, m, i, j):
        """FIXME! briefly describe function

        :param m: MatGSO object
        :param i: start row
        :param j: stop row

        """
        self.i = i
        self.j = j
        self.m = m

    def __enter__(self):
        """
        Enter context for working on rows.

        """
        self.m.row_op_begin(self.i, self.j)

    def __exit__(self, exception_type, exception_value, exception_traceback):
        """
        Exit context for working on rows.

        :param exception_type:
        :param exception_value:
        :param exception_traceback:

        """
        self.m.row_op_end(self.i, self.j)


cdef class MatGSO:
    """
    """

    def __init__(self, IntegerMatrix B, U=None, UinvT=None,
                 int flags=GSO_DEFAULT, float_type="double"):
        """FIXME! briefly describe function

        :param IntegerMatrix B:
        :param IntegerMatrix U:
        :param IntegerMatrix UinvT:
        :param int flags:
        :param float_type:
        :returns:
        :rtype:

        """

        if U is None:
            self._U = IntegerMatrix(0, 0)
        elif isinstance(U, IntegerMatrix):
            self._U = U
            self._U.gen_identity(B.nrows)

        if UinvT is None:
            self._UinvT = IntegerMatrix(0, 0)
        elif isinstance(UinvT, IntegerMatrix):
            self._UinvT = UinvT
            self._UinvT.gen_identity(B.nrows)

        cdef Matrix[Z_NR[mpz_t]] *b = <Matrix[Z_NR[mpz_t]]*>B._core
        cdef Matrix[Z_NR[mpz_t]] *u = <Matrix[Z_NR[mpz_t]]*>self._U._core
        cdef Matrix[Z_NR[mpz_t]] *u_inv_t = <Matrix[Z_NR[mpz_t]]*>self._UinvT._core

        if float_type == "double":
            self._type = mpz_double
            self._core.mpz_double = new MatGSO_c[Z_NR[mpz_t],FP_NR[double]](b[0], u[0], u_inv_t[0], flags)
        elif float_type == "dd":
            self._type = mpz_dd
            self._core.mpz_dd = new MatGSO_c[Z_NR[mpz_t],FP_NR[dd_real]](b[0], u[0], u_inv_t[0], flags)
        elif float_type == "qd":
            self._type = mpz_qd
            self._core.mpz_qd = new MatGSO_c[Z_NR[mpz_t],FP_NR[qd_real]](b[0], u[0], u_inv_t[0], flags)
        elif float_type == "mpfr":
            self._type = mpz_mpfr
            self._core.mpz_mpfr = new MatGSO_c[Z_NR[mpz_t],FP_NR[mpfr_t]](b[0], u[0], u_inv_t[0], flags)
        else:
            raise ValueError("Float type '%s' not understood."%float_type)

        self._B = B

    def __dealloc__(self):
        """FIXME! briefly describe function

        :returns:
        :rtype:

        """
        if self._type == mpz_double:
            del self._core.mpz_double
        if self._type == mpz_dd:
            del self._core.mpz_dd
        if self._type == mpz_qd:
            del self._core.mpz_qd
        if self._type == mpz_mpfr:
            del self._core.mpz_mpfr

    @property
    def float_type(self):
        if self._type == mpz_double:
            return "double"
        if self._type == mpz_dd:
            return "dd"
        if self._type == mpz_qd:
            return "qd"
        if self._type == mpz_mpfr:
            return "mpfr"

    @property
    def d(self):
        """
        """
        if self._type == mpz_double:
            return self._core.mpz_double.d
        elif self._type == mpz_dd:
            return self._core.mpz_dd.d
        elif self._type == mpz_qd:
            return self._core.mpz_qd.d
        elif self._type == mpz_mpfr:
            return self._core.mpz_mpfr.d
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

    @property
    def int_gram_enabled(self):
        """
        """
        if self._type == mpz_double:
            return bool(self._core.mpz_double.enableIntGram)
        elif self._type == mpz_dd:
            return bool(self._core.mpz_dd.enableIntGram)
        elif self._type == mpz_qd:
            return bool(self._core.mpz_qd.enableIntGram)
        elif self._type == mpz_mpfr:
            return bool(self._core.mpz_mpfr.enableIntGram)
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

    @property
    def row_expo_enabled(self):
        """
        """
        if self._type == mpz_double:
            return bool(self._core.mpz_double.enableRowExpo)
        elif self._type == mpz_dd:
            return bool(self._core.mpz_dd.enableRowExpo)
        elif self._type == mpz_qd:
            return bool(self._core.mpz_qd.enableRowExpo)
        elif self._type == mpz_mpfr:
            return bool(self._core.mpz_mpfr.enableRowExpo)
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

    @property
    def transform_enabled(self):
        """
        """
        if self._type == mpz_double:
            return bool(self._core.mpz_double.enableTransform)
        elif self._type == mpz_dd:
            return bool(self._core.mpz_dd.enableTransform)
        elif self._type == mpz_qd:
            return bool(self._core.mpz_qd.enableTransform)
        elif self._type == mpz_mpfr:
            return bool(self._core.mpz_mpfr.enableTransform)
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

    @property
    def inv_transform_enabled(self):
        """
        """
        if self._type == mpz_double:
            return bool(self._core.mpz_double.enableInvTransform)
        elif self._type == mpz_dd:
            return bool(self._core.mpz_dd.enableInvTransform)
        elif self._type == mpz_qd:
            return bool(self._core.mpz_qd.enableInvTransform)
        elif self._type == mpz_mpfr:
            return bool(self._core.mpz_mpfr.enableInvTransform)
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

    @property
    def row_op_force_long(self):
        """
        """
        if self._type == mpz_double:
            return bool(self._core.mpz_double.rowOpForceLong)
        elif self._type == mpz_dd:
            return bool(self._core.mpz_dd.rowOpForceLong)
        elif self._type == mpz_qd:
            return bool(self._core.mpz_qd.rowOpForceLong)
        elif self._type == mpz_mpfr:
            return bool(self._core.mpz_mpfr.rowOpForceLong)
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

    def row_op_begin(self, int first, int last):
        """FIXME! briefly describe function

        :param int first:
        :param int last:
        :returns:
        :rtype:

        """
        if self._type == mpz_double:
            return self._core.mpz_double.rowOpBegin(first, last)
        elif self._type == mpz_dd:
            return self._core.mpz_dd.rowOpBegin(first, last)
        elif self._type == mpz_qd:
            return self._core.mpz_qd.rowOpBegin(first, last)
        elif self._type == mpz_mpfr:
            return self._core.mpz_mpfr.rowOpBegin(first, last)
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

    def row_op_end(self, int first, int last):
        """FIXME! briefly describe function

        :param int first:
        :param int last:
        :returns:
        :rtype:

        """
        if self._type == mpz_double:
            return self._core.mpz_double.rowOpEnd(first, last)
        elif self._type == mpz_dd:
            return self._core.mpz_dd.rowOpEnd(first, last)
        elif self._type == mpz_qd:
            return self._core.mpz_qd.rowOpEnd(first, last)
        elif self._type == mpz_mpfr:
            return self._core.mpz_mpfr.rowOpEnd(first, last)
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

    def row_ops(self, int first, int last):
        """FIXME! briefly describe function

        :param int first:
        :param int last:

        """
        return MatGSORowOpContext(self, first, last)

    def get_gram(self, int i, int j):
        """
        Return Gram matrix coefficients (0 ≤ i ≤ n_known_rows and 0 ≤ j ≤ i).
        If `enable_row_expo=False`, returns the dot product `<b_i, b_j>`.  If
        `enable_row_expo=True`, returns `<b_i, b_j>/ 2^(row_expo_i +
        row_expo_j)`.

        :param int i:
        :param int j:

        :returns:

        :rtype:
        """
        preprocess_indices(i, j, self.d, self.d)

        cdef FP_NR[double] t_double
        cdef FP_NR[dd_real] t_dd
        cdef FP_NR[qd_real] t_qd
        cdef FP_NR[mpfr_t] t_mpfr

        if self._type == mpz_double:
            self._core.mpz_double.getGram(t_double, i, j)
            return t_double.getData()
        elif self._type == mpz_dd:
            # TODO: don't just return doubles
            self._core.mpz_dd.getGram(t_dd, i, j)
            return t_dd.get_d()
        elif self._type == mpz_qd:
            # TODO: don't just return doubles
            self._core.mpz_qd.getGram(t_qd, i, j)
            return t_qd.get_d()
        elif self._type == mpz_mpfr:
            # TODO: don't just return doubles
            self._core.mpz_mpfr.getGram(t_mpfr, i, j)
            return t_mpfr.get_d()
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

    def get_r(self, int i, int j):
        """
        Return `<b_i, b*_j>`.

        :param i:
        :param j:

        :returns:

        :rtype: double
        """
        preprocess_indices(i, j, self.d, self.d)
        cdef FP_NR[double] t_double
        cdef FP_NR[dd_real] t_dd
        cdef FP_NR[qd_real] t_qd
        cdef FP_NR[mpfr_t] t_mpfr

        if self._type == mpz_double:
            self._core.mpz_double.getR(t_double, i, j)
            return t_double.getData()
        elif self._type == mpz_dd:
            # TODO: don't just return doubles
            self._core.mpz_dd.getR(t_dd, i, j)
            return t_dd.get_d()
        elif self._type == mpz_qd:
            # TODO: don't just return doubles
            self._core.mpz_qd.getR(t_qd, i, j)
            return t_qd.get_d()
        elif self._type == mpz_mpfr:
            # TODO: don't just return doubles
            self._core.mpz_mpfr.getR(t_mpfr, i, j)
            return t_mpfr.get_d()
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

    def get_r_exp(self, int i, int j):
        """
        Return `f = r(i, j)` and expo such that `<b_i, b*_j>` = f * 2^expo`.  If
        `enable_row_expo=False`, `expo` is always 0.  If `enable_row_expo=True`,
        `expo = row_expo[i] + row_expo[j]`

        It is assumed that `r(i, j)` is valid.

        :param i:
        :param j:

        :returns:

        :rtype: (float, int)
        """
        preprocess_indices(i, j, self.d, self.d)
        cdef double r = 0.0
        cdef long expo = 0

        if self._type == mpz_double:
            r = self._core.mpz_double.getRExp(i, j, expo).getData()
        elif self._type == mpz_dd:
            # TODO: don't just return doubles
            r = self._core.mpz_dd.getRExp(i, j, expo).get_d()
        elif self._type == mpz_qd:
            # TODO: don't just return doubles
            r = self._core.mpz_qd.getRExp(i, j, expo).get_d()
        elif self._type == mpz_mpfr:
            # TODO: don't just return doubles
            r = self._core.mpz_mpfr.getRExp(i, j, expo).get_d()
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

        return r, expo


    def get_mu(self, int i, int j):
        """
        Return `<b_i, b*_j> / ||b*_j||^2`.

        :param i:
        :param j:
        :returns:
        :rtype: double

        """
        preprocess_indices(i, j, self.d, self.d)
        cdef FP_NR[double] t_double
        cdef FP_NR[dd_real] t_dd
        cdef FP_NR[qd_real] t_qd
        cdef FP_NR[mpfr_t] t_mpfr

        if self._type == mpz_double:
            self._core.mpz_double.getMu(t_double, i, j)
            return t_double.getData()
        elif self._type == mpz_dd:
            # TODO: don't just return doubles
            self._core.mpz_dd.getMu(t_dd, i, j)
            return t_dd.get_d()
        elif self._type == mpz_qd:
            # TODO: don't just return doubles
            self._core.mpz_qd.getMu(t_qd, i, j)
            return t_qd.get_d()
        elif self._type == mpz_mpfr:
            # TODO: don't just return doubles
            self._core.mpz_mpfr.getMu(t_mpfr, i, j)
            return t_mpfr.get_d()
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

    def get_mu_exp(self, int i, int j):
        """
        Return `f = mu(i, j)` and `expo` such that `f * 2^expo = (b_i, b*_j) /
        ||b*_j||^2`.  If `enable_row_expo=False`, `expo` is always zero.  If
        `enable_row_expo=True`, `expo = rowExpo[i] - rowExpo[j]`.  It is assumed
        that `mu(i, j)` is valid.

        :param i:
        :param j:

        :returns:

        :rtype: (float, int)
        """
        preprocess_indices(i, j, self.d, self.d)
        cdef double r = 0.0
        cdef long expo = 0

        if self._type == mpz_double:
            r = self._core.mpz_double.getMuExp(i, j, expo).getData()
        elif self._type == mpz_dd:
            # TODO: don't just return doubles
            r = self._core.mpz_dd.getMuExp(i, j, expo).get_d()
        elif self._type == mpz_qd:
            # TODO: don't just return doubles
            r = self._core.mpz_qd.getMuExp(i, j, expo).get_d()
        elif self._type == mpz_mpfr:
            # TODO: don't just return doubles
            r = self._core.mpz_mpfr.getMuExp(i, j, expo).get_d()
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

        return r, expo


    def update_gso(self):
        """
        Updates all GSO coefficients (mu and r).
        """
        if self._type == mpz_double:
            return bool(self._core.mpz_double.updateGSO())
        elif self._type == mpz_dd:
            return bool(self._core.mpz_dd.updateGSO())
        elif self._type == mpz_qd:
            return bool(self._core.mpz_qd.updateGSO())
        elif self._type == mpz_mpfr:
            return bool(self._core.mpz_mpfr.updateGSO())
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

    def discover_all_rows(self):
        """
        Allows `row_addmul(_we)` for all rows even if the GSO has never been
        computed.
        """
        if self._type == mpz_double:
            self._core.mpz_double.discoverAllRows()
        elif self._type == mpz_dd:
            self._core.mpz_dd.discoverAllRows()
        elif self._type == mpz_qd:
            self._core.mpz_qd.discoverAllRows()
        elif self._type == mpz_mpfr:
            self._core.mpz_mpfr.discoverAllRows()
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

    def move_row(self, int old_r, int new_r):
        """FIXME! briefly describe function

        :param int old_r:
        :param int new_r:
        :returns:
        :rtype:

        """
        preprocess_indices(old_r, new_r, self.d, self.d)
        if self._type == mpz_double:
            return self._core.mpz_double.moveRow(old_r, new_r)
        elif self._type == mpz_dd:
            return self._core.mpz_dd.moveRow(old_r, new_r)
        elif self._type == mpz_qd:
            return self._core.mpz_qd.moveRow(old_r, new_r)
        elif self._type == mpz_mpfr:
            return self._core.mpz_mpfr.moveRow(old_r, new_r)
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)


        # void setR(int i, int j, FT& f)
        # void swapRows(int row1, int row2)

    def row_addmul(self, int i, int j, x):
        """FIXME! briefly describe function

        :param int i:
        :param int j:
        :param x:
        :returns:
        :rtype:

        """
        preprocess_indices(i, j, self.d, self.d)
        cdef double x_ = x
        cdef FP_NR[double] x_double
        cdef FP_NR[dd_real] x_dd
        cdef FP_NR[qd_real] x_qd
        cdef FP_NR[mpfr_t] x_mpfr

        if self._type == mpz_double:
            x_double = x_
            self._core.mpz_double.row_addmul(i, j, x_double)
        elif self._type == mpz_dd:
            x_dd = x_
            self._core.mpz_dd.row_addmul(i, j, x_dd)
        elif self._type == mpz_qd:
            x_qd = x_
            self._core.mpz_qd.row_addmul(i, j, x_qd)
        elif self._type == mpz_mpfr:
            x_mpfr = x_
            self._core.mpz_mpfr.row_addmul(i, j, x_mpfr)
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

    def create_row(self):
        """FIXME! briefly describe function

        :returns:
        :rtype:

        """
        if self._type == mpz_double:
            return self._core.mpz_double.createRow()
        elif self._type == mpz_dd:
            return self._core.mpz_dd.createRow()
        elif self._type == mpz_qd:
            return self._core.mpz_qd.createRow()
        elif self._type == mpz_mpfr:
            return self._core.mpz_mpfr.createRow()
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

    def remove_last_row(self):
        """FIXME! briefly describe function

        :returns:
        :rtype:

        """
        if self._type == mpz_double:
            return self._core.mpz_double.removeLastRow()
        elif self._type == mpz_dd:
            return self._core.mpz_dd.removeLastRow()
        elif self._type == mpz_qd:
            return self._core.mpz_qd.removeLastRow()
        elif self._type == mpz_mpfr:
            return self._core.mpz_mpfr.removeLastRow()
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)


    def get_current_slope(self, int start_row, int stop_row):
        """FIXME! briefly describe function

        :param int start_row:
        :param int stop_row:
        :returns:

        .. note:: we call ``getCurrentSlope`` which is declared in bkz.h

        """
        if self._type == mpz_double:
            return getCurrentSlope[FP_NR[double]](self._core.mpz_double[0], start_row, stop_row)
        elif self._type == mpz_dd:
            return getCurrentSlope[FP_NR[dd_real]](self._core.mpz_dd[0], start_row, stop_row)
        elif self._type == mpz_qd:
            return getCurrentSlope[FP_NR[qd_real]](self._core.mpz_qd[0], start_row, stop_row)
        elif self._type == mpz_mpfr:
            return getCurrentSlope[FP_NR[mpfr_t]](self._core.mpz_mpfr[0], start_row, stop_row)
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)


    def compute_gaussian_heuristic_distance(self, int kappa, int block_size,
                                            double max_dist, int max_dist_expo,
                                            double gh_factor):
        """FIXME! briefly describe function

        :param int kappa:
        :param int block_size:
        :param double max_dist:
        :param int max_dist_expo:
        :param double gh_factor:
        :returns: (max_dist, max_dist_expo)


        .. note:: we call ``computeGaussianHeurDist`` which is declared in bkz.h

        """

        cdef FP_NR[double] max_dist_double
        cdef FP_NR[dd_real] max_dist_dd
        cdef FP_NR[qd_real] max_dist_qd
        cdef FP_NR[mpfr_t] max_dist_mpfr

        if self._type == mpz_double:
            max_dist_double = max_dist
            computeGaussHeurDist[FP_NR[double]](self._core.mpz_double[0],
                                                max_dist_double, max_dist_expo, kappa, block_size, gh_factor)
            max_dist = max_dist_double.get_d()
        elif self._type == mpz_dd:
            max_dist_dd = max_dist
            computeGaussHeurDist[FP_NR[dd_real]](self._core.mpz_dd[0],
                                                 max_dist_dd, max_dist_expo, kappa, block_size, gh_factor)
            max_dist = max_dist_dd.get_d()
        elif self._type == mpz_qd:
            max_dist_qd = max_dist
            computeGaussHeurDist[FP_NR[qd_real]](self._core.mpz_qd[0],
                                                 max_dist_qd, max_dist_expo, kappa, block_size, gh_factor)
            max_dist = max_dist_qd.get_d()
        elif self._type == mpz_mpfr:
            max_dist_mpfr = max_dist
            computeGaussHeurDist[FP_NR[mpfr_t]](self._core.mpz_mpfr[0],
                                                max_dist_mpfr, max_dist_expo, kappa, block_size, gh_factor)
            max_dist = max_dist_mpfr.get_d()
        else:
            raise RuntimeError("MatGSO object '%s' has no core."%self)

        return max_dist, max_dist_expo




class GSO:
    DEFAULT=GSO_DEFAULT
    INT_GRAM=GSO_INT_GRAM
    ROW_EXPO=GSO_ROW_EXPO
    OP_FORCE_LONG=GSO_OP_FORCE_LONG
    Mat = MatGSO
