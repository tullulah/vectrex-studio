# Test case for nested array access in conditions
a = [1, 2, 3]
b = [1, 2, 3]

def test():
    i = 0
    j = 0

    # Nested array access in condition
    if a[i] == b[j]:
        pass

    # Complex condition with logical operators
    if (a[i] == 1 and b[j] == 2) or (a[i] == 3):
        pass

    # While loop with nested array access
    while a[i] < b[j]:
        i = i + 1
        j = j + 1
