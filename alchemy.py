from alchemyapi import AlchemyAPI
import json

alchemyapi = AlchemyAPI()

demo_text='I had a trip in Dalian, China in summer 2008.'
response = alchemyapi.entities('text', demo_text)

if response['status'] == 'OK':
    for entity in response['entities']:
        print('text: ', entity['text'].encode('utf-8'))
        print('type: ', entity['type'])
        print('')
else:
    print('Error in entity extraction call: ', response['statusInfo'])