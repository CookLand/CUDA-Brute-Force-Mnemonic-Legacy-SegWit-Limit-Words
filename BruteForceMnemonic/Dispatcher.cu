﻿/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V2.0.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#include <stdafx.h>

#include <iostream>
#include <chrono>
#include <thread>
#include <fstream>
#include <string>
#include <memory>
#include <sstream>
#include <iomanip>
#include <vector>
#include <map>
#include <omp.h>



#include "Dispatcher.h"
#include "GPU.h"
#include "KernelStride.hpp"
#include "Helper.h"


#include "cuda_runtime.h"
#include "device_launch_parameters.h"


#include "../Tools/tools.h"
#include "../Tools/utils.h"
#include "../config/Config.hpp"
#include "../Tools/segwit_addr.h"


//std::string find_words[NUM_FIND_WORDS_INDICES] = {
//"solar",
//"wild",
//"evidence",
//"regular",
//"cancel",
//"across",
//"apple",
//"neutral",
//"hold",
//"book",
//"puzzle",
//"system",
//"satisfy",
//"faculty",
//"matrix",
//"table",
//"speed",
//"pilot",
//"fury",
//"wood",
//"city",
////"family",
//"book",
//"pool",
//"monitor",
////"online",
//"fire",
//"total",
//"autumn",
//"outside",
//"speed",
//"raven",
//"abandon",
//"coin"
//};

static std::thread save_thread;

int Generate_Mnemonic(void)
{
	cudaError_t cudaStatus = cudaSuccess;
	int err;
	ConfigClass Config;
	//uint16_t find_words_indices[NUM_FIND_WORDS_INDICES];
	std::vector<uint16_t> words_indices[12];

	try {
		parse_config(&Config, "config.cfg");
		err = tools::stringToWordIndices(Config.static_words_generate_mnemonic + " ?", Config.words_indicies_mnemonic);
		if (err != 0)
		{
			std::cerr << "Error stringToWordIndices()!" << std::endl;
			return -1;
		}
		for (int i = 0; i < 12; i++)
			if (tools::stringToWordIndices(Config.wordlist_word[i], words_indices[i]) != 0)
			{
				std::cerr << "Error stringToWordIndices() \"wordlist_word_" << i << "\"!" << std::endl;
				return -1;
			}

		uint64_t number_of_generated_mnemonics = (Config.number_of_generated_mnemonics / (Config.cuda_block * Config.cuda_grid)) * (Config.cuda_block * Config.cuda_grid);
		if ((Config.number_of_generated_mnemonics % (Config.cuda_block * Config.cuda_grid)) != 0) number_of_generated_mnemonics += Config.cuda_block * Config.cuda_grid;
		Config.number_of_generated_mnemonics = number_of_generated_mnemonics;
	}
	catch (...) {
		for (;;)
			std::this_thread::sleep_for(std::chrono::seconds(30));
	}


	//for (int i = 0; i < NUM_FIND_WORDS_INDICES; i++)
	//{
	//	err = tools::getWordIndices(find_words[i], &find_words_indices[i]);
	//	if (err != 0)
	//	{
	//		std::cerr << "Error getWordIndices()!" << std::endl;
	//		return -1;
	//	}
	//}

	devicesInfo();
	uint32_t num_device = 0;
#ifndef TEST_MODE
	std::cout << "\n\nEnter number of device: ";
	std::cin >> num_device;
#endif //TEST_MODE
	cudaStatus = cudaSetDevice(num_device);
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaSetDevice failed!  Do you have a CUDA-capable GPU installed?");
		return -1;
	}

	size_t num_wallets_gpu = Config.cuda_grid * Config.cuda_block;
	if (num_wallets_gpu < NUM_PACKETS_SAVE_IN_FILE)
	{
		std::cerr << "Error num_wallets_gpu < NUM_PACKETS_SAVE_IN_FILE!" << std::endl;
		return -1;
	}
	uint32_t num_bytes = 0;
	if (Config.chech_equal_bytes_in_adresses == "yes")
	{
#ifdef TEST_MODE
		num_bytes = 8;
#else
		num_bytes = 8;
#endif //TEST_MODE
	}

	std::cout << "\nNUM WALLETS IN PACKET GPU: " << tools::formatWithCommas(num_wallets_gpu) << std::endl << std::endl;
	data_class* Data = new data_class();
	stride_class* Stride = new stride_class(Data);



	std::cout << "READ TABLES! WAIT..." << std::endl;
	tools::clearFiles();
	if ((Config.generate_path[0] != 0) || (Config.generate_path[1] != 0) || (Config.generate_path[2] != 0) || (Config.generate_path[3] != 0) || (Config.generate_path[4] != 0)
		|| (Config.generate_path[5] != 0))
	{
		std::cout << "READ TABLES LEGACY(BIP32, BIP44)..." << std::endl;
		err = tools::readAllTables(Data->host.tables_legacy, Config.folder_tables_legacy, "");
		if (err == -1) {
			std::cerr << "Error readAllTables legacy!" << std::endl;
			goto Error;
		}
	}
	if ((Config.generate_path[6] != 0) || (Config.generate_path[7] != 0))
	{
		std::cout << "READ TABLES SEGWIT(BIP49)..." << std::endl;
		err = tools::readAllTables(Data->host.tables_segwit, Config.folder_tables_segwit, "");
		if (err == -1) {
			std::cerr << "Error readAllTables segwit!" << std::endl;
			goto Error;
		}
	}
	if ((Config.generate_path[8] != 0) || (Config.generate_path[9] != 0))
	{
		std::cout << "READ TABLES NATIVE SEGWIT(BIP84)..." << std::endl;
		err = tools::readAllTables(Data->host.tables_native_segwit, Config.folder_tables_native_segwit, "");
		if (err == -1) {
			std::cerr << "Error readAllTables native segwit!" << std::endl;
			goto Error;
		}
	}
	std::cout << std::endl << std::endl;


	for (int i = 0; i < 12; i++)
	{
		size_t size = words_indices[i].size() * 2;
		Data->host.wordlist[i].table = (uint16_t*)malloc(size);
		if (Data->host.wordlist[i].table == NULL) {
			std::cerr << "Error allocate wordlist["<< i <<"]!" << std::endl;
			goto Error;
		}
		Data->host.wordlist[i].size = (uint32_t)size;
		for (int x = 0; x < size/2; x++)
		{
			Data->host.wordlist[i].table[x] = words_indices[i][x];
		}
	}

	if (Data->malloc(Config.cuda_grid, Config.cuda_block, Config.num_paths, Config.num_child_addresses, Config.save_generation_result_in_file == "yes" ? true : false) != 0) {
		std::cerr << "Error Data->malloc()!" << std::endl;
		goto Error;
	}

	if (Stride->init() != 0) {
		std::cerr << "Error INIT!!" << std::endl;
		goto Error;
	}

	Data->host.freeTableBuffers();

	std::cout << "START GENERATE ADDRESSES!" << std::endl;
	std::cout << "PATH: " << std::endl;
	if (Config.generate_path[0] != 0) std::cout << "m/0/0.." << (Config.num_child_addresses - 1) << std::endl;
	if (Config.generate_path[1] != 0) std::cout << "m/1/0.." << (Config.num_child_addresses - 1) << std::endl;
	if (Config.generate_path[2] != 0) std::cout << "m/0/0/0.." << (Config.num_child_addresses - 1) << std::endl;
	if (Config.generate_path[3] != 0) std::cout << "m/0/1/0.." << (Config.num_child_addresses - 1) << std::endl;
	if (Config.generate_path[4] != 0) std::cout << "m/44'/0'/0'/0/0.." << (Config.num_child_addresses - 1) << std::endl;
	if (Config.generate_path[5] != 0) std::cout << "m/44'/0'/0'/1/0.." << (Config.num_child_addresses - 1) << std::endl;
	if (Config.generate_path[6] != 0) std::cout << "m/49'/0'/0'/0/0.." << (Config.num_child_addresses - 1) << std::endl;
	if (Config.generate_path[7] != 0) std::cout << "m/49'/0'/0'/1/0.." << (Config.num_child_addresses - 1) << std::endl;
	if (Config.generate_path[8] != 0) std::cout << "m/84'/0'/0'/0/0.." << (Config.num_child_addresses - 1) << std::endl;
	if (Config.generate_path[9] != 0) std::cout << "m/84'/0'/0'/1/0.." << (Config.num_child_addresses - 1) << std::endl;
	std::cout << "\nGENERATE " << tools::formatWithCommas(Config.number_of_generated_mnemonics) << " MNEMONICS. " << tools::formatWithCommas(Config.number_of_generated_mnemonics * Data->num_all_childs) << " ADDRESSES. MNEMONICS IN ROUNDS " << tools::formatWithCommas(Data->wallets_in_round_gpu) << ". WAIT...\n\n";

	tools::generateRandomUint16Buffer(Data->host.words_pos, Data->size_words_pos_buf/2, Data->host.wordlist);

	if (cudaMemcpyToSymbol(dev_num_bytes_find, &num_bytes, 4, 0, cudaMemcpyHostToDevice) != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol to num_bytes_find failed!" << std::endl;
		goto Error;
	}
	if (cudaMemcpyToSymbol(dev_generate_path, &Config.generate_path, sizeof(Config.generate_path), 0, cudaMemcpyHostToDevice) != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol to dev_generate_path failed!" << std::endl;
		goto Error;
	}
	if (cudaMemcpyToSymbol(dev_num_childs, &Config.num_child_addresses, 4, 0, cudaMemcpyHostToDevice) != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol to dev_num_child failed!" << std::endl;
		goto Error;
	}
	if (cudaMemcpyToSymbol(dev_num_paths, &Config.num_paths, 4, 0, cudaMemcpyHostToDevice) != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol to dev_num_paths failed!" << std::endl;
		goto Error;
	}
	if (cudaMemcpyToSymbol(dev_static_words_indices, &Config.words_indicies_mnemonic, 12 * 2, 0, cudaMemcpyHostToDevice) != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol to dev_gen_words_indices failed!" << std::endl;
		goto Error;
	}
	if (cudaMemcpyToSymbol(dev_rounds_check_validity, &Config.rounds_check_validity, 4, 0, cudaMemcpyHostToDevice) != cudaSuccess)
	{
		std::cerr << "cudaMemcpyToSymbol to dev_rounds_check_validity failed!" << std::endl;
		goto Error;
	}
	

	//if (cudaMemcpyToSymbol(dev_find_words_indices, find_words_indices, NUM_FIND_WORDS_INDICES * 2, 0, cudaMemcpyHostToDevice) != cudaSuccess)
	//{
	//	std::cerr << "cudaMemcpyToSymbol to dev_gen_words_indices failed!" << std::endl;
	//	goto Error;
	//}

	for (uint64_t step = 0; step < Config.number_of_generated_mnemonics / (Data->wallets_in_round_gpu); step++)
	{
		tools::start_time();

		if (Config.save_generation_result_in_file == "yes") {
			if (Stride->start_for_save(Config.cuda_grid, Config.cuda_block) != 0) {
				std::cerr << "Error START!!" << std::endl;
				goto Error;
			}
		}
		else
		{
			if (Stride->start(Config.cuda_grid, Config.cuda_block) != 0) {
				std::cerr << "Error START!!" << std::endl;
				goto Error;
			}
		}

		tools::generateRandomUint16Buffer(Data->host.words_pos, Data->size_words_pos_buf/2, Data->host.wordlist);;

		if (save_thread.joinable()) save_thread.join();

		if (Config.save_generation_result_in_file == "yes") {
			if (Stride->end_for_save() != 0) {
				std::cerr << "Error END!!" << std::endl;
				goto Error;
			}
		}
		else
		{
			if (Stride->end() != 0) {
				std::cerr << "Error END!!" << std::endl;
				goto Error;
			}
		}

		if (Config.save_generation_result_in_file == "yes") {
			save_thread = std::thread(&tools::saveResult, (char*)Data->host.mnemonic, (uint8_t*)Data->host.hash160, Data->wallets_in_round_gpu, Data->num_all_childs, Data->num_childs, Config.generate_path);
			//tools::saveResult((char*)Data->host.mnemonic, (uint8_t*)Data->host.hash160, Data->wallets_in_round_gpu, Data->num_all_childs, Data->num_childs, Config.generate_path);
		}

		tools::checkResult(Data->host.ret);

		float delay;
		tools::stop_time_and_calc(&delay);
		std::cout << "\rSPEED: " << std::setw(8) << std::fixed << tools::formatWithCommas((float)Data->wallets_in_round_gpu / (delay / 1000.0f)) << " MNEMONICS/SECOND AND "
			<< tools::formatWithCommas(((float)Data->wallets_in_round_gpu * Data->num_all_childs) / (delay / 1000.0f)) << " ADDRESSES/SECOND, ROUND: " << step;

	}
	std::cout << "\n\nEND!" << std::endl;
	if (save_thread.joinable()) save_thread.join();
	// cudaDeviceReset must be called before exiting in order for profiling and
	// tracing tools such as Nsight and Visual Profiler to show complete traces.
	cudaStatus = cudaDeviceReset();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceReset failed!");
		return -1;
	}

	return 0;
Error:
	std::cout << "\n\nERROR!" << std::endl;
	if (save_thread.joinable()) save_thread.join();
	// cudaDeviceReset must be called before exiting in order for profiling and
	// tracing tools such as Nsight and Visual Profiler to show complete traces.
	cudaStatus = cudaDeviceReset();
	if (cudaStatus != cudaSuccess) {
		fprintf(stderr, "cudaDeviceReset failed!");
		return -1;
	}

	return -1;
}







