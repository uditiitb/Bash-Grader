import matplotlib.pyplot as plt
import csv

def load_data(filename):
    data = {}
    try:
        with open(filename, 'r') as file:
            reader = csv.DictReader(file)
            for row in reader:
                name = row['Name']
                scores = [float(row[col]) if row[col] != 'a' else 0 for col in row if col not in ['Roll_Number', 'Name', 'total']]
                data[name] = scores
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found.")
    return data

def generate_line_graph(data):
    plt.figure(figsize=(10, 6))
    for name, scores in data.items():
        plt.plot(range(1, len(scores) + 1), scores, label=name)

    plt.xlabel('Exam Number')
    plt.ylabel('Score')
    plt.title('Individual Exam Performance')  
    plt.legend()
    plt.tight_layout()
    plt.savefig('line_graph.png', dpi=300, bbox_inches='tight',format="png")
    plt.show()
data = load_data('main.csv')


generate_line_graph(data)