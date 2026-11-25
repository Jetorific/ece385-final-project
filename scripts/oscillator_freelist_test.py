class OscillatorBank:
    def __init__(self, num_oscillators):
        if num_oscillators < 4:
            raise ValueError("An oscillator bank must contain at least 4 oscillators")

        self.oscillators = [Oscillator() for _ in range(num_oscillators)]
        for i in range(num_oscillators):
            self.oscillators[i].next = (i + 1) % num_oscillators
            self.oscillators[i].prev = (i - 1) % num_oscillators

        self.head = 0

    def __str__(self):
        rows = ["OscillatorBank: head", "Osc #\tHead\tFree\tNext\tPrev"]
        rows.extend(
            f"{i}\t{'H' if i == self.head else ''}\t"
            f"{'x' if oscillator.free else ''}\t"
            f"{oscillator.next}\t{oscillator.prev}"
            for i, oscillator in enumerate(self.oscillators)
        )
        return "\n".join(rows)

    def get_free(self):
        return self.oscillators[self.head] if self.oscillators[self.head].free else None
    
    def use(self):
        oscillator_index = self.head
        oscillator = self.oscillators[oscillator_index]
        self.head = oscillator.next
        oscillator.free = False
        return oscillator_index

    def free(self, oscillator_index):
        oscillator = self.oscillators[oscillator_index]
        previous = oscillator.prev
        following = oscillator.next

        self.oscillators[previous].next = following
        self.oscillators[following].prev = previous

        old_head = following if oscillator_index == self.head else self.head
        previous = self.oscillators[old_head].prev
        self.oscillators[previous].next = oscillator_index
        oscillator.prev = previous
        oscillator.next = old_head
        self.oscillators[old_head].prev = oscillator_index
        self.head = oscillator_index
        oscillator.free = True
        return oscillator_index

class Oscillator:
    def __init__(self):
        self.free = True
        self.next = None
        self.prev = None

    def __repr__(self):
        return f"Oscillator(free={self.free}, next={self.next}, prev={self.prev})"

NUM_OSCILLATORS = 8

def main():
    oscillator_bank = OscillatorBank(NUM_OSCILLATORS)

    print("\n"*5)
    print(oscillator_bank)
    print(f"Using oscillator: {oscillator_bank.use()}")
    print(oscillator_bank)

    print(f"Using oscillator: {oscillator_bank.use()}")
    print(oscillator_bank)

    print(f"Using oscillator: {oscillator_bank.use()}")
    print(oscillator_bank)

    print(f"Freeing oscillator: {oscillator_bank.free(1)}")
    print(oscillator_bank)

    print(f"Using oscillator: {oscillator_bank.use()}")
    print(f"Using oscillator: {oscillator_bank.use()}")
    print(f"Using oscillator: {oscillator_bank.use()}")
    print(f"Using oscillator: {oscillator_bank.use()}")
    print(oscillator_bank)

    print(f"Freeing oscillator: {oscillator_bank.free(3)}")
    print(oscillator_bank)

    print(f"Using oscillator: {oscillator_bank.use()}")
    print(f"Using oscillator: {oscillator_bank.use()}")
    print(oscillator_bank)

    print(f"Using oscillator: {oscillator_bank.use()}")
    print(oscillator_bank)

    print(f"Using oscillator: {oscillator_bank.use()}")
    print(oscillator_bank)

    print(f"Freeing oscillator: {oscillator_bank.free(4)}")
    print(oscillator_bank)

    print(f"Freeing oscillator: {oscillator_bank.free(0)}")
    print(oscillator_bank)

    print(f"Using oscillator: {oscillator_bank.use()}")
    print(oscillator_bank)

    print(f"Using oscillator: {oscillator_bank.use()}")
    print(oscillator_bank)

    print(f"Using oscillator: {oscillator_bank.use()}")
    print(oscillator_bank)

    print(f"Using oscillator: {oscillator_bank.use()}")
    print(f"Using oscillator: {oscillator_bank.use()}")
    print(f"Using oscillator: {oscillator_bank.use()}")
    print(f"Using oscillator: {oscillator_bank.use()}")
    print(f"Using oscillator: {oscillator_bank.use()}")
    print(f"Using oscillator: {oscillator_bank.use()}")
    print(f"Using oscillator: {oscillator_bank.use()}")
    print(f"Using oscillator: {oscillator_bank.use()}")
    print(f"Using oscillator: {oscillator_bank.use()}")
    print(f"Using oscillator: {oscillator_bank.use()}")
    print(oscillator_bank)

if __name__ == "__main__":
    main()