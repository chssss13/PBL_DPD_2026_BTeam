#pragma once
#ifndef DATA_COPY_UTILS_H
#define DATA_COPY_UTILS_H

#include <ap_int.h>

// 1D 복사: 단순 벡터 복사 (e.g. x_seq[t] -> layer_in[0])
template <int D, typename T>
void copy_row(const T in[D], T out[D]) {
#pragma HLS INLINE
    for (int i = 0; i < D; i++) {
#pragma HLS UNROLL
        out[i] = in[i];
    }
}

// 2D 복사: in[row_idx] → out[row_idx]
template <int ROW, int COL, typename T>
void copy_row_by_index(const T in[ROW][COL], int in_idx,
                       T out[ROW][COL], int out_idx) {
#pragma HLS INLINE
    for (int i = 0; i < COL; i++) {
#pragma HLS UNROLL
        out[out_idx][i] = in[in_idx][i];
    }
}

// 2D 전체 복사: in → out
template <int ROW, int COL, typename T>
void copy_2d(const T in[ROW][COL], T out[ROW][COL]) {
#pragma HLS INLINE
    for (int r = 0; r < ROW; r++) {
#pragma HLS UNROLL
        for (int c = 0; c < COL; c++) {
#pragma HLS UNROLL
            out[r][c] = in[r][c];
        }
    }
}

// 2D → 1D 복사: in[row_idx] → out
template <int COL, typename T>
void copy_row_to_vector(const T in[][COL], int row_idx, T out[COL]) {
#pragma HLS INLINE
    for (int i = 0; i < COL; i++) {
#pragma HLS UNROLL
        out[i] = in[row_idx][i];
    }
}

// 1D → 2D 복사: in → out[row_idx]
template <int COL, typename T>
void copy_vector_to_row(const T in[COL], T out[][COL], int row_idx) {
#pragma HLS INLINE
    for (int i = 0; i < COL; i++) {
#pragma HLS UNROLL
        out[row_idx][i] = in[i];
    }
}

#endif // DATA_COPY_UTILS_H