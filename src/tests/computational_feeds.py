import numpy as np

import numpy as np


def calculate_twap():
    prices= [4000 + cur_idx * 100 for cur_idx in range(0,6)]  # Sample prices
    timestamps = [1710691526 + cur_idx * 1000 for cur_idx in range(0,6)]  # Sample prices
    intervals = np.diff(timestamps)

    # Calculate the sum of price times interval
    sum_price_interval = sum(prices[i] * intervals[i] for i in range(len(intervals)))

    # Calculate the sum of intervals
    sum_intervals = sum(intervals)

    # Calculate TWAP
    twap = sum_price_interval / sum_intervals

    print("TWAP: ", twap)

def calculate_ema(number_of_period):
    # Generate random data
    np.random.seed(0)  # for reproducibility
    max_iteration = 30
    data_test_1 = [(4000 + cur_idx * 100) *10**8 for cur_idx in range(max_iteration)]

    # Calculate exponential moving average (EMA)
    alpha = 2 / (number_of_period + 1)
    ema = [4000 * 10**8]  # initialize the EMA list with the TWAP
    # Calculate EMA for the remaining data
    for i in range(len(data_test_1)-number_of_period+1, len(data_test_1)):
        ema_value = alpha * data_test_1[i] + (1 - alpha) * ema[-1]  # calculate EMA using the formula
        ema.append(ema_value)

    print("Data points:", data_test_1)
    print("Exponential Moving Average (EMA):", ema)
    print(len(ema))
    return ema


def calculate_macd(): 
    # Generate random data
    np.random.seed(0)  # for reproducibility
    max_iteration = 10
    data_test_1 = [(4000 + cur_idx * 100) *10**8 for cur_idx in range(max_iteration)]

    # Calculate MACD
    short_ema = calculate_ema(12)
    long_ema = calculate_ema(26)
    print(len(short_ema))
    print(len(long_ema))
    macd = [short_ema[i] - long_ema[len(long_ema)-len(short_ema) +i] for i in range(len(short_ema))]

    print("Data points:", data_test_1)
    print("MACD:", macd)
    print(len(macd))



calculate_macd()