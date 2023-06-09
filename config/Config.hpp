/**
  ******************************************************************************
  * @author		Anton Houzich
  * @version	V2.0.0
  * @date		28-April-2023
  * @mail		houzich_anton@mail.ru
  * discussion  https://t.me/BRUTE_FORCE_CRYPTO_WALLET
  ******************************************************************************
  */
#pragma once
#include <string>
#include <vector>
  //#include <tao/config.hpp>

struct ConfigClass
{
public:
	std::string folder_tables_legacy = "";
	std::string folder_tables_segwit = "";
	std::string folder_tables_native_segwit = "";

	uint64_t number_of_generated_mnemonics = 0;
	uint64_t num_child_addresses = 0;

	std::string path_m0_x = "";
	std::string path_m1_x = "";
	std::string path_m0_0_x = "";
	std::string path_m0_1_x = "";
	std::string path_m44h_0h_0h_0_x = "";
	std::string path_m44h_0h_0h_1_x = "";
	std::string path_m49h_0h_0h_0_x = "";
	std::string path_m49h_0h_0h_1_x = "";
	std::string path_m84h_0h_0h_0_x = "";
	std::string path_m84h_0h_0h_1_x = "";

	uint32_t generate_path[10] = { 0 };
	uint32_t num_paths = 0;


	int16_t words_indicies_mnemonic[12] = { 0 };
	std::string static_words_generate_mnemonic = "";
	std::string chech_equal_bytes_in_adresses = "";
	std::string save_generation_result_in_file = "";

	//std::vector< tao::config::value > wordlist_word_0;
	std::string wordlist_word[12] = { "" };

	uint32_t rounds_check_validity = 0;

	uint64_t cuda_grid = 0;
	uint64_t cuda_block = 0;
public:
	ConfigClass()
	{
	}
	~ConfigClass()
	{
	}
};


int parse_config(ConfigClass* config, std::string path);

