# Test case to verify stack balance in conditional branches
a = [1, 2, 3]

def test():
    i = 0

    if a[i] == 1:
        pass

    # Another test with OR
    if a[i] == 1 or a[i] == 2:
        pass

    # Nested iteration
    while a[i] < 5:
        i = i + 1
