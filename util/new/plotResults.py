
import matplotlib.pyplot as plt
import os
import sys
import numpy as np

input_directory = sys.argv[1]
attribute = "wall_clock_time_in_seconds"

# Get the data from the file
def get_data(dateipfad, attribut):
    with open(dateipfad, "r") as datei:
        zeilen = datei.readlines()
        header = zeilen[0].split("\t")
        daten_zeile = zeilen[1].split("\t")
        spalten_index = header.index(attribut)
        return daten_zeile[spalten_index]

layout_list = []
layout_list_index = []
build_list = []
build_list_index = []
search_list = []
search_list_index = []
full_time_list = []

# Get the data
for filename in os.listdir(input_directory):
    if filename.endswith(".layout.time"):
        layout_list.append(get_data(input_directory + '/' + filename, attribute))
        layout_list_index.append(filename.split('.')[0])
    elif filename.endswith(".index.time"):
        build_list.append(get_data(input_directory + '/' + filename, attribute))
        build_list_index.append(filename.split('.')[0])
    elif filename.endswith(".time"):
        search_list.append(get_data(input_directory + '/' + filename, attribute))
        search_list_index.append(filename.split('.')[0])

# Sort the data
layout_list, layout_list_index = zip(*sorted(zip(layout_list, layout_list_index), key=lambda x: int(x[1])))
build_list, build_list_index = zip(*sorted(zip(build_list, build_list_index), key=lambda x: int(x[1])))
search_list, search_list_index = zip(*sorted(zip(search_list, search_list_index), key=lambda x: int(x[1])))

layout_list = [float(i) for i in layout_list]
build_list = [float(i) for i in build_list]
search_list = [float(i) for i in search_list]

full_time_list = [a + b + c for a, b, c in zip(layout_list, build_list, search_list)]
full_time_list_index = layout_list_index

# Plot the data
fig, axs = plt.subplots(2, 2, figsize=(12, 12))

axs[0,0].plot(layout_list_index, layout_list)
axs[0,0].set_title('Layout Directory List')

axs[0,1].plot(build_list_index, build_list)
axs[0,1].set_title('Build Directory List')

axs[1,0].plot(search_list_index, search_list)
axs[1,0].set_title('Search Directory List')

axs[1,1].plot(full_time_list_index, full_time_list)
axs[1,1].set_title('Full Time')

plt.tight_layout()

# Check if the file already exists
if os.path.exists('plot.png'):
    iterator = 1
    while os.path.exists('plot_{iterator}.png'):
        iterator += 1
    filename = f'plot_{iterator}.png'
else:
    filename = 'plot.png'

plt.savefig(filename)
