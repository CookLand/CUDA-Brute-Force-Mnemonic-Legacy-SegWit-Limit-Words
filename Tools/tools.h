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
#include <vector>
#include <string>
#include "../BruteForceMnemonic/stdafx.h"
namespace tools {

	void generateRandomUint64Buffer(uint64_t* buff, size_t len);
	void generateRandomUint8Buffer(uint8_t* buff, size_t len, uint8_t limit);
	void generateRandomUint16Buffer(uint16_t* buff, size_t len, wordlistStruct* wordlists);
	int pushToMemory(uint8_t* addr_buff, std::vector<std::string>& lines, int max_len);
	int readAllTables(tableStruct* tables, std::string path, std::string prefix);
	void clearFiles(void);
	void saveResult(char* mnemonic, uint8_t* hash160, size_t num_wallets, size_t num_all_childs, size_t num_childs, uint32_t path_generate[10]);
	int checkResult(retStruct* ret);
	int stringToWordIndices(std::string str, int16_t* gen_words_indices);
	int stringToWordIndices(std::string str, std::vector<uint16_t>& words_indices);
	void Test();
	int getWordIndices(std::string str, uint16_t* gen_words_indices);
}