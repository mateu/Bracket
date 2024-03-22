def generate_pairs(start, end):
    """
    Generate parent games for region rounds 2-4
    Helps determine the seed of the winning team
    If the winning team is the lower seed
    then there are extra points added to the score
    """
    w = 0
    for _ in range(0, 4):
        z = 0
        for x in range(start, end + 1):
            for _ in range(1, 3):
                z = z+1
                yield (x+w*15, z+w*15)
        w = w + 1

for x, y in generate_pairs(9, 15):
    print(f"({x}, {y}),")
