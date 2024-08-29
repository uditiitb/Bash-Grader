import matplotlib.pyplot as plt
import csv

def load_data(filename):
    data = {}
    try:
        with open(filename, 'r') as file:
            reader = csv.DictReader(file)
            for row in reader:
                name = row['Name']
                scores = [float(row[col]) for col in row if col not in ['Roll_Number', 'Name', 'total'] and row[col] != 'a']
                data[name] = sum(scores)
    except FileNotFoundError:
        print(f"Error: File '{filename}' not found.")
    return data

def generate_bar_chart(data):
    names = list(data.keys())
    scores = list(data.values())

    plt.figure(figsize=(10, 6))
    plt.bar(names, scores)
    plt.xlabel('Student Name')
    plt.ylabel('Overall Performance')
    plt.title('Overall Performance Bar Chart')
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig('bar_chart.png', dpi=300, bbox_inches='tight',format="png")
    plt.show()
data = load_data('main.csv')


generate_bar_chart(data)