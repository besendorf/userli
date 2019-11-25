<?php

namespace App\Traits;

trait PublicKeyTrait
{
    /**
     * @var string|null
     */
    public $publicKey;

    public function getPublicKey(): ?string
    {
        return $this->publicKey;
    }

    /**
     * @param string|null $publicKey
     */
    public function setPublicKey($publicKey): void
    {
        $this->publicKey = $publicKey;
    }
}
